//
//  RemarkMatcher.swift
//  Pocket Ledger
//
//  The one definition of "this remark matches this term", used by Insights
//  (buckets, Remark Lookup), the bucket editor's preview, and RemarkBucket.
//
//  A remark has two kinds of content:
//  - words — usually who you paid: "Starbucks", "Joe's Coffee"
//  - #tags — a deliberate label for why: "#work", "#datenight"
//
//  Term syntax (case never matters):
//    star          words starting with "star"        Starbucks ✓  Mustard ✗
//    "bar"         exactly the word "bar"            Bar ✓        Barber ✗
//    joe's coffee  those words in order, the last    Joe's Coffeehouse ✓
//                  one by prefix
//    #work         exactly the tag #work             #work ✓      #workout ✗
//    *bean         anywhere in the remark            Coffeebean ✓
//
//  `nonisolated` because the project's default actor isolation is MainActor
//  and this runs inside InsightsEngine's background work.
//

import Foundation

// MARK: - Term

nonisolated enum RemarkTerm: Hashable, Sendable {
    /// Words in order; every word must be equal except the last, which
    /// matches by prefix unless `exact`.
    case words([String], exact: Bool)
    /// A hashtag, without "#", lowercased.
    case tag(String)
    /// Substring anywhere in the remark (the "*" escape hatch).
    case anywhere(String)
}

// MARK: - Tokens

/// A remark split once, so it can be checked against many terms cheaply.
nonisolated struct RemarkTokens: Sendable {
    let lowercased: String
    /// Lowercased words, punctuation trimmed. Tag bodies are included, so
    /// the term "coffee" also catches "#coffee".
    let words: [String]
    /// Lowercased hashtags without "#".
    let tags: Set<String>
}

// MARK: - Matcher

nonisolated enum RemarkMatcher {

    // MARK: Parsing terms

    /// Parses one bucket or lookup term. Returns nil for empty input.
    static func parse(_ raw: String) -> RemarkTerm? {
        var text = normalized(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if text.hasPrefix("#") {
            let body = tagBody(text.dropFirst())
            return body.isEmpty ? nil : .tag(body)
        }

        if text.hasPrefix("*") {
            let rest = text.drop(while: { $0 == "*" })
                .trimmingCharacters(in: CharacterSet(charactersIn: "*"))
                .trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? nil : .anywhere(rest)
        }

        var exact = false
        if text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") {
            text = String(text.dropFirst().dropLast())
            exact = true
        }
        // A trailing "*" just restates the default prefix rule.
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "*"))

        let words = splitWords(text)
        return words.isEmpty ? nil : .words(words, exact: exact)
    }

    static func parse(_ raws: [String]) -> [RemarkTerm] {
        raws.compactMap(parse)
    }

    // MARK: Tokenizing remarks

    static func tokens(of remark: String) -> RemarkTokens {
        var tags = Set<String>()
        for token in remark.split(whereSeparator: { $0.isWhitespace }) where token.hasPrefix("#") {
            let body = tagBody(token.dropFirst())
            if !body.isEmpty { tags.insert(body) }
        }
        let lower = normalized(remark)
        return RemarkTokens(lowercased: lower,
                            words: splitWords(lower),
                            tags: tags)
    }

    // MARK: Matching

    static func matches(_ tokens: RemarkTokens, _ term: RemarkTerm) -> Bool {
        switch term {
        case .tag(let tag):
            return tokens.tags.contains(tag)

        case .anywhere(let text):
            return tokens.lowercased.contains(text)

        case .words(let termWords, let exact):
            guard let last = termWords.last, tokens.words.count >= termWords.count else { return false }
            let leading = termWords.dropLast()
            for start in 0...(tokens.words.count - termWords.count) {
                var ok = true
                for (offset, word) in leading.enumerated() where tokens.words[start + offset] != word {
                    ok = false
                    break
                }
                guard ok else { continue }
                let candidate = tokens.words[start + termWords.count - 1]
                if exact ? candidate == last : candidate.hasPrefix(last) { return true }
            }
            return false
        }
    }

    /// True when the remark matches ANY of the terms.
    static func matches(_ tokens: RemarkTokens, anyOf terms: [RemarkTerm]) -> Bool {
        terms.contains { matches(tokens, $0) }
    }

    static func matches(_ remark: String, anyOf terms: [RemarkTerm]) -> Bool {
        guard !remark.isEmpty, !terms.isEmpty else { return false }
        return matches(tokens(of: remark), anyOf: terms)
    }

    // MARK: Hashtags for display

    /// The remark split into plain text and hashtags, in order, for styling
    /// tags differently. A "#" only starts a tag at the beginning of the
    /// remark or after whitespace, so "C#" and "no.#1" stay plain.
    static func segments(of remark: String) -> [(text: String, isTag: Bool)] {
        var result: [(text: String, isTag: Bool)] = []
        var plain = ""
        var index = remark.startIndex

        while index < remark.endIndex {
            let ch = remark[index]
            let atBoundary = index == remark.startIndex || remark[remark.index(before: index)].isWhitespace
            if ch == "#", atBoundary {
                var end = remark.index(after: index)
                while end < remark.endIndex, isTagCharacter(remark[end]) {
                    end = remark.index(after: end)
                }
                if end > remark.index(after: index) {
                    if !plain.isEmpty { result.append((text: plain, isTag: false)); plain = "" }
                    result.append((text: String(remark[index..<end]), isTag: true))
                    index = end
                    continue
                }
            }
            plain.append(ch)
            index = remark.index(after: index)
        }
        if !plain.isEmpty { result.append((text: plain, isTag: false)) }
        return result
    }

    /// Hashtags in a remark, as written (without "#").
    static func hashtags(in remark: String) -> [String] {
        segments(of: remark).filter { $0.isTag }.map { String($0.text.dropFirst()) }
    }

    // MARK: Helpers

    /// Lowercased, with curly apostrophes made straight: iOS Smart
    /// Punctuation types "Joe’s", and the term "joe's" should still match.
    static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
    }

    static func isTagCharacter(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "_" || ch == "-"
    }

    /// The tag characters at the start of `text`, lowercased.
    private static func tagBody<S: StringProtocol>(_ text: S) -> String {
        String(text.prefix(while: { isTagCharacter($0) })).lowercased()
    }

    /// Words split on whitespace and common separators, with surrounding
    /// punctuation trimmed. Internal apostrophes survive ("joe's").
    static func splitWords(_ text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "/,;:+&()[]{}|-"))
        let trimSet = CharacterSet.punctuationCharacters.union(.symbols)
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: trimSet) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Corpus (bucket editor preview)

/// Every distinct remark with how many transactions use it, tokenized
/// once, so the bucket editor can preview matches on each keystroke.
nonisolated struct RemarkCorpus: Sendable {
    struct Entry: Sendable {
        let remark: String
        let tokens: RemarkTokens
        let count: Int
    }

    let entries: [Entry]

    /// - Parameter plugCategoryIDs: plugs are skipped. Transfer pairs are
    ///   counted once, by their outflow leg.
    init(transactions: [Transaction], plugCategoryIDs: Set<UUID>) {
        var counts: [String: (remark: String, count: Int)] = [:]
        for tx in transactions {
            if tx.linkedTransactionID != nil {
                guard case .outflow = tx.type else { continue }
            } else if plugCategoryIDs.contains(tx.categoryID) {
                continue
            }
            let trimmed = tx.remark.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            counts[key, default: (trimmed, 0)].count += 1
        }
        entries = counts.values
            .map { Entry(remark: $0.remark, tokens: RemarkMatcher.tokens(of: $0.remark), count: $0.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.remark < $1.remark }
    }

    /// Transactions matching a single term.
    func count(matching term: RemarkTerm) -> Int {
        entries.reduce(0) { RemarkMatcher.matches($1.tokens, term) ? $0 + $1.count : $0 }
    }

    /// Distinct remarks matching any term, most used first.
    func entries(matchingAnyOf terms: [RemarkTerm]) -> [Entry] {
        guard !terms.isEmpty else { return [] }
        return entries.filter { RemarkMatcher.matches($0.tokens, anyOf: terms) }
    }
}
