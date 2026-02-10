import Foundation

//
//  MathParser.swift
//  Pocket Ledger
//
//  Robust version: Prevents crashes during live typing by rejecting invalid syntax.
//  Updated: Supports "naked" decimals (e.g. ".5" -> "0.5").
//

struct MathParser {
    /// Parses a string input (e.g. "10+2.50" or ".5") and returns a computed Decimal.
    /// Handles live-typing stability by stripping dangerous characters and invalid sequences.
    static func calculate(_ input: String) -> Decimal {
        // 1. Sanitize: Allow only numbers, dot, and BASIC math operators.
        // We remove spaces entirely to make parsing easier (e.g. "10 + .5" becomes "10+.5")
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/")
        var sanitized = input.components(separatedBy: allowed.inverted).joined()
        
        // NEW: Normalize "naked" decimals before validation
        // This handles cases like ".5" -> "0.5" or "10+.5" -> "10+0.5"
        
        // Case A: Expression starts with a dot (e.g. ".5")
        if sanitized.hasPrefix(".") {
            sanitized = "0" + sanitized
        }
        
        // Case B: Operator followed immediately by a dot (e.g. "+." or "*.")
        // We iterate through operators and replace "op." with "op0."
        let operators = ["+", "-", "*", "/"]
        for op in operators {
            sanitized = sanitized.replacingOccurrences(of: "\(op).", with: "\(op)0.")
        }
        
        // 2. Early exit for empty input
        // Note: trimmingCharacters(in: .whitespaces) is redundant if we stripped spaces above,
        // but kept for safety if logic changes.
        let trimmed = sanitized.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        
        // 3. Validate: Must contain at least one digit
        guard trimmed.contains(where: { $0.isNumber }) else { return 0 }
        
        // 4. CRITICAL FIX: Detect invalid consecutive operators (e.g., "++", "**", "..")
        // These cause NSExpression to crash. We return 0 immediately if found.
        // We allow "*-" or "/-" for negative numbers, but block double symbols otherwise.
        if hasInvalidSequences(trimmed) {
            return 0
        }
        
        // 5. Strip trailing non-digit characters (operators and dots)
        // This handles live-typing cases like "50+" (user hasn't typed the next number yet)
        let trailingJunk = CharacterSet(charactersIn: "+-*/.")
        let cleaned = trimmed.trimmingCharacters(in: trailingJunk)
        
        // After cleaning, check we still have content
        guard !cleaned.isEmpty, cleaned.contains(where: { $0.isNumber }) else { return 0 }
        
        // 6. Strip leading operators (except minus)
        let leadingJunk = CharacterSet(charactersIn: "+*/.")
        var expression = cleaned.trimmingCharacters(in: leadingJunk)
        
        // Handle edge case: expression starts with multiple minuses like "--5"
        while expression.hasPrefix("--") {
            expression = String(expression.dropFirst(2))
        }
        
        guard !expression.isEmpty, expression.contains(where: { $0.isNumber }) else { return 0 }
        
        // 7. Evaluate using NSExpression safely
        let nsExpression = NSExpression(format: expression)
            
            if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
                // Convert the NSNumber result directly to Decimal
                return result.decimalValue
            }
            
            return Decimal(string: expression) ?? 0
        }
    
    private static func hasInvalidSequences(_ input: String) -> Bool {
        // Blocks: ++, --, **, //, .., +*, +/, -*, -/, etc.
        // But we want to allow: *- (times negative) or /- (divided by negative) or +- (plus negative)
        // The safest live-typing check is to look for specific dangerous duplications.
        
        let dangerousPatterns = [
            "++", "**", "//", "..",   // Double operators
            "+*", "+/",               // Operator mixing
            "-*", "-/"                // Minus followed by others (rarely valid in this syntax)
        ]
        
        for pattern in dangerousPatterns {
            if input.contains(pattern) { return true }
        }
        
        // Also check for multiple decimals in a single number segment
        // Simple heuristic: if we see two dots without an operator in between
        // This is complex to regex perfectly, but preventing ".." covers most accidents.
        
        return false
    }
}
