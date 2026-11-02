import Foundation

//
//  MathParser.swift
//  Pocket Ledger
//
//  Evaluates amount-field arithmetic ("45/2", "12.50+3*2", "(30+15)/3")
//  entirely in Decimal. Earlier versions handed the string to NSExpression,
//  which did integer division on whole numbers ("45/2" gave 22), routed
//  results through Double ("0.1+0.2" was not exactly 0.30), and raised an
//  uncatchable Objective-C exception on some malformed input ("1.2.3").
//
//  Grammar (standard precedence, left-associative):
//      expression := term (("+" | "-") term)*
//      term       := factor (("*" | "/") factor)*
//      factor     := ("+" | "-") factor | number | "(" expression ")"
//

struct MathParser {

    /// Number of fraction digits results are rounded to. Matches the
    /// two-decimal display used throughout the app.
    static let fractionDigits = 2

    /// Parses an amount expression and returns the result rounded to cents.
    /// Returns 0 for empty, invalid, or incomplete input, and for division by
    /// zero, so callers can treat "not a positive number" uniformly.
    static func calculate(_ input: String, locale: Locale = .current) -> Decimal {
        evaluate(input, locale: locale) ?? 0
    }

    /// Like `calculate`, but returns nil when the input can't be evaluated,
    /// so a UI can tell "invalid" apart from a genuine zero.
    static func evaluate(_ input: String, locale: Locale = .current) -> Decimal? {
        let tokens = tokenize(prepare(input, locale: locale))
        guard let tokens, tokens.contains(where: { if case .number = $0 { return true } else { return false } }) else {
            return nil
        }
        var parser = Parser(tokens: tokens)
        guard let value = parser.parseExpression(), parser.isAtEnd else { return nil }
        return roundedToCents(value)
    }

    // MARK: - Input preparation

    /// Normalises symbols, the locale's decimal separator, and live-typing
    /// leftovers, so "45 ÷ 2", "4,50" (comma locales) and "50+" all parse.
    static func prepare(_ input: String, locale: Locale = .current) -> String {
        var s = input
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")   // Unicode minus
        // Note: the letter "x" is deliberately NOT treated as multiply, so
        // stray text ("approx 50") is dropped rather than becoming "*50".

        // Comma: decimal point in comma locales ("4,50"), otherwise a
        // grouping separator ("1,000") that can safely be dropped.
        let usesDecimalComma = (locale.decimalSeparator ?? ".") == ","
        s = s.replacingOccurrences(of: ",", with: usesDecimalComma ? "." : "")

        // Keep only characters the grammar understands; currency symbols,
        // spaces and letters are dropped.
        let allowed = Set("0123456789.+-*/()")
        s = String(s.filter { allowed.contains($0) })

        // Live typing: ignore a dangling operator or decimal point at the end
        // ("50+", "12.") and any unclosed parentheses ("(10+5").
        while let last = s.last, "+-*/(.".contains(last) {
            s.removeLast()
        }
        let open = s.filter { $0 == "(" }.count
        let close = s.filter { $0 == ")" }.count
        if open > close {
            s += String(repeating: ")", count: open - close)
        }
        return s
    }

    // MARK: - Tokenizer

    enum Token: Equatable {
        case number(Decimal)
        case plus, minus, times, divide
        case openParen, closeParen
    }

    /// Splits prepared input into tokens. Returns nil for malformed numbers
    /// such as "1.2.3" or a lone ".".
    static func tokenize(_ s: String) -> [Token]? {
        var tokens: [Token] = []
        var index = s.startIndex

        while index < s.endIndex {
            let ch = s[index]
            switch ch {
            case "+": tokens.append(.plus);       index = s.index(after: index)
            case "-": tokens.append(.minus);      index = s.index(after: index)
            case "*": tokens.append(.times);      index = s.index(after: index)
            case "/": tokens.append(.divide);     index = s.index(after: index)
            case "(": tokens.append(.openParen);  index = s.index(after: index)
            case ")": tokens.append(.closeParen); index = s.index(after: index)
            default:
                // Number: digits with at most one decimal point.
                var literal = ""
                var seenDot = false
                while index < s.endIndex, s[index].isASCII, s[index].isNumber || s[index] == "." {
                    if s[index] == "." {
                        if seenDot { return nil }   // "1.2.3"
                        seenDot = true
                    }
                    literal.append(s[index])
                    index = s.index(after: index)
                }
                guard literal.contains(where: { $0.isNumber }) else { return nil } // lone "."
                if literal.hasPrefix(".") { literal = "0" + literal }   // ".5"
                if literal.hasSuffix(".") { literal.removeLast() }      // "5."
                // Decimal(string:) is locale-sensitive; the POSIX locale
                // guarantees "." is read as the decimal point.
                guard let value = Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX")) else {
                    return nil
                }
                tokens.append(.number(value))
            }
        }
        return tokens
    }

    // MARK: - Parser

    private struct Parser {
        let tokens: [Token]
        var position = 0
        /// Guards against pathological nesting like "((((((…" or "------…".
        private var depth = 0
        private static let maxDepth = 64

        init(tokens: [Token]) { self.tokens = tokens }

        var isAtEnd: Bool { position >= tokens.count }

        private var current: Token? { isAtEnd ? nil : tokens[position] }

        private mutating func advance() { position += 1 }

        mutating func parseExpression() -> Decimal? {
            guard var value = parseTerm() else { return nil }
            while let token = current, token == .plus || token == .minus {
                advance()
                guard let rhs = parseTerm() else { return nil }
                value = (token == .plus) ? value + rhs : value - rhs
            }
            return value
        }

        private mutating func parseTerm() -> Decimal? {
            guard var value = parseFactor() else { return nil }
            while let token = current, token == .times || token == .divide {
                advance()
                guard let rhs = parseFactor() else { return nil }
                if token == .times {
                    value *= rhs
                } else {
                    guard rhs != 0 else { return nil }   // division by zero
                    value /= rhs
                }
            }
            return value
        }

        private mutating func parseFactor() -> Decimal? {
            depth += 1
            defer { depth -= 1 }
            guard depth <= Self.maxDepth, let token = current else { return nil }

            switch token {
            case .plus:
                advance()
                return parseFactor()
            case .minus:
                advance()
                return parseFactor().map { -$0 }
            case .number(let value):
                advance()
                return value
            case .openParen:
                advance()
                guard let value = parseExpression(), current == .closeParen else { return nil }
                advance()
                return value
            default:
                return nil   // e.g. "5*/2" or ")"
            }
        }
    }

    // MARK: - Rounding

    private static func roundedToCents(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, fractionDigits, .plain)
        return result
    }
}
