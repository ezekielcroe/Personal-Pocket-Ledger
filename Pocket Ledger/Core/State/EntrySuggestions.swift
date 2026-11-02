//
//  EntrySuggestions.swift
//  Pocket Ledger
//
//  Everything the transaction form uses to cut mechanical effort without
//  making decisions for the user: remark autocomplete (whole remarks and
//  single words), the "Last time" recall, suggested categories, and the
//  last-used account. All of it is derived from existing transactions —
//  nothing new is stored.
//

import Foundation

// MARK: - Suggestion

struct RemarkSuggestion: Hashable, Identifiable, Sendable {
    enum Kind: Hashable, Sendable {
        /// A whole past remark, e.g. "Anniversary dinner". Replaces the text.
        case phrase
        /// A single word completing the word being typed.
        case word
    }

    let text: String
    let kind: Kind
    /// Whether Return/Tab may accept this suggestion. True only for a prefix
    /// match ("Star" → "Starbucks") when what's typed isn't already a word or
    /// remark you've used. "Contains" matches need a deliberate tap, so
    /// "bean" + Return can't silently become "coffeebean", and a finished
    /// word like "coffee" + Return stays "coffee".
    let canAutoAccept: Bool
    /// The phrase's usual category, if known (shown as an emoji).
    let usualCategoryID: UUID?

    var id: String { "\(kind)-\(text.lowercased())" }
}

// MARK: - Remark Index

/// A one-pass summary of every remark in a book. Built once and cached by
/// `TransactionStore` until transactions change, instead of rescanning all
/// history on every keystroke.
struct RemarkIndex: Sendable {

    struct Phrase: Sendable {
        var text: String          // most recently used casing
        var count: Int
        var lastUsed: Date
        var categoryCounts: [UUID: Int]
        var typeCounts: [TransactionType: Int]

        var usualCategoryID: UUID? {
            categoryCounts.max { a, b in a.value != b.value ? a.value < b.value : a.key.uuidString > b.key.uuidString }?.key
        }
    }

    struct Word: Sendable {
        var text: String
        var count: Int
        var lastUsed: Date
    }

    private(set) var phrases: [String: Phrase] = [:]
    private(set) var words: [String: Word] = [:]
    /// Hashtags, keyed by lowercased body (no "#"); text keeps your casing.
    private(set) var tags: [String: Word] = [:]
    /// Latest inflow/outflow (not a transfer leg) per "type|remark" key.
    private(set) var latest: [String: Transaction] = [:]

    /// - Parameter systemCategoryIDs: Transfer and reconciliation categories.
    ///   Plugs are skipped entirely so "Reconciliation adjustment" never
    ///   shows up as a suggestion or as "Last time".
    init(transactions: [Transaction], systemCategoryIDs: Set<UUID>) {
        for tx in transactions {
            let isTransferLeg = tx.linkedTransactionID != nil
            // Both legs of a transfer carry the same remark; count it once.
            if isTransferLeg && tx.type != .outflow { continue }
            if !isTransferLeg && systemCategoryIDs.contains(tx.categoryID) { continue }

            let trimmed = tx.remark.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            let effectiveType: TransactionType = isTransferLeg ? .transfer : tx.type

            // Phrase
            var phrase = phrases[key] ?? Phrase(text: trimmed, count: 0, lastUsed: tx.date,
                                                categoryCounts: [:], typeCounts: [:])
            phrase.count += 1
            if tx.date >= phrase.lastUsed {
                phrase.lastUsed = tx.date
                phrase.text = trimmed
            }
            if !isTransferLeg { phrase.categoryCounts[tx.categoryID, default: 0] += 1 }
            phrase.typeCounts[effectiveType, default: 0] += 1
            phrases[key] = phrase

            // Words
            for word in Self.words(in: trimmed) {
                let wordKey = word.lowercased()
                var entry = words[wordKey] ?? Word(text: word, count: 0, lastUsed: tx.date)
                entry.count += 1
                if tx.date >= entry.lastUsed {
                    entry.lastUsed = tx.date
                    entry.text = word
                }
                words[wordKey] = entry
            }

            // Hashtags
            for tag in RemarkMatcher.hashtags(in: trimmed) {
                let tagKey = tag.lowercased()
                var entry = tags[tagKey] ?? Word(text: tag, count: 0, lastUsed: tx.date)
                entry.count += 1
                if tx.date >= entry.lastUsed {
                    entry.lastUsed = tx.date
                    entry.text = tag
                }
                tags[tagKey] = entry
            }

            // Latest, for "Last time"
            if !isTransferLeg {
                let latestKey = Self.latestKey(remark: key, type: tx.type)
                if let existing = latest[latestKey] {
                    if tx.date >= existing.date { latest[latestKey] = tx }
                } else {
                    latest[latestKey] = tx
                }
            }
        }
    }

    // MARK: Queries

    /// Suggestions for the remark field.
    /// - Empty remark: the most-used remarks, favouring the chosen category.
    /// - Text ending in a space: none (the user has finished a word).
    /// - Otherwise: whole remarks that start with the text, then words that
    ///   complete the word being typed (prefix matches before "contains").
    func suggestions(for remark: String,
                     type: TransactionType,
                     categoryID: UUID?,
                     limit: Int = 3) -> [RemarkSuggestion] {
        let typed = remark.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if typed.isEmpty {
            return rankedPhrases(phrases.values.filter { ($0.typeCounts[type] ?? 0) > 0 },
                                 type: type, categoryID: categoryID)
                .prefix(limit)
                .map { RemarkSuggestion(text: $0.text, kind: .phrase, canAutoAccept: false,
                                        usualCategoryID: $0.usualCategoryID) }
        }

        if let last = remark.last, last.isWhitespace { return [] }

        let fragment = Self.currentFragment(of: remark).lowercased()
        let stem = Self.textBeforeFragment(of: remark).lowercased()

        // Typing a hashtag: suggest only tags you've used, by prefix.
        if fragment.hasPrefix("#") {
            return tagSuggestions(completing: String(fragment.dropFirst()), limit: limit)
        }
        // Typed text that is already a complete, known word or remark should
        // be left alone by Return — suggestions are still shown for tapping.
        let typedIsKnown = phrases[typed] != nil || words[fragment] != nil

        // Whole remarks starting with everything typed so far.
        let phraseMatches = rankedPhrases(
            phrases.filter { $0.key.hasPrefix(typed) && $0.key != typed }.map(\.value),
            type: type, categoryID: categoryID
        )
        var results: [RemarkSuggestion] = phraseMatches.prefix(2).map {
            RemarkSuggestion(text: $0.text, kind: .phrase, canAutoAccept: !typedIsKnown,
                             usualCategoryID: $0.usualCategoryID)
        }

        // Words completing the current fragment.
        if !fragment.isEmpty {
            let wordMatches = words
                .filter { $0.key.contains(fragment) && $0.key != fragment }
                .map { (key: $0.key, word: $0.value, isPrefix: $0.key.hasPrefix(fragment)) }
                .sorted { a, b in
                    if a.isPrefix != b.isPrefix { return a.isPrefix }
                    if a.word.count != b.word.count { return a.word.count > b.word.count }
                    if a.word.lastUsed != b.word.lastUsed { return a.word.lastUsed > b.word.lastUsed }
                    return a.key < b.key
                }
            let phraseResults = Set(results.map { $0.text.lowercased() })
            for match in wordMatches where results.count < limit {
                // Skip a word whose completed remark equals a phrase already shown.
                if phraseResults.contains(stem + match.key) { continue }
                results.append(RemarkSuggestion(text: match.word.text, kind: .word,
                                                canAutoAccept: match.isPrefix && !typedIsKnown,
                                                usualCategoryID: nil))
            }
        }
        return Array(results.prefix(limit))
    }

    /// Hashtags starting with `body` (without "#"), most used first. An
    /// empty body lists your top tags; those aren't auto-accepted.
    func tagSuggestions(completing body: String, limit: Int) -> [RemarkSuggestion] {
        let q = body.lowercased()
        let typedIsKnown = tags[q] != nil
        return tags
            .filter { q.isEmpty || ($0.key.hasPrefix(q) && $0.key != q) }
            .sorted { a, b in
                if a.value.count != b.value.count { return a.value.count > b.value.count }
                if a.value.lastUsed != b.value.lastUsed { return a.value.lastUsed > b.value.lastUsed }
                return a.key < b.key
            }
            .prefix(limit)
            .map { RemarkSuggestion(text: "#" + $0.value.text, kind: .word,
                                    canAutoAccept: !q.isEmpty && !typedIsKnown, usualCategoryID: nil) }
    }

    /// Words containing `fragment` (prefix matches first). Used by the
    /// bucket editor's term suggestions.
    func wordSuggestions(completing fragment: String, limit: Int) -> [String] {
        let q = fragment.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return words
            .filter { q.isEmpty || $0.key.contains(q) }
            .filter { $0.key != q }
            .sorted { a, b in
                let ap = q.isEmpty || a.key.hasPrefix(q), bp = q.isEmpty || b.key.hasPrefix(q)
                if ap != bp { return ap }
                if a.value.count != b.value.count { return a.value.count > b.value.count }
                if a.value.lastUsed != b.value.lastUsed { return a.value.lastUsed > b.value.lastUsed }
                return a.key < b.key
            }
            .prefix(limit)
            .map { $0.value.text }
    }

    /// The most recent inflow/outflow with exactly this remark.
    func lastTransaction(withRemark remark: String, type: TransactionType) -> Transaction? {
        let key = remark.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        return latest[Self.latestKey(remark: key, type: type)]
    }

    // MARK: Helpers

    private func rankedPhrases(_ list: [Phrase], type: TransactionType, categoryID: UUID?) -> [Phrase] {
        list.sorted { a, b in
            if let categoryID {
                let ac = a.categoryCounts[categoryID] ?? 0, bc = b.categoryCounts[categoryID] ?? 0
                if (ac > 0) != (bc > 0) { return ac > 0 }
            }
            let at = a.typeCounts[type] ?? 0, bt = b.typeCounts[type] ?? 0
            if (at > 0) != (bt > 0) { return at > 0 }
            if a.count != b.count { return a.count > b.count }
            if a.lastUsed != b.lastUsed { return a.lastUsed > b.lastUsed }
            return a.text.lowercased() < b.text.lowercased()
        }
    }

    private static func latestKey(remark: String, type: TransactionType) -> String {
        "\(type.rawValue)|\(remark)"
    }

    /// The word being typed: everything after the last whitespace.
    static func currentFragment(of remark: String) -> String {
        if let lastSpace = remark.lastIndex(where: { $0.isWhitespace }) {
            return String(remark[remark.index(after: lastSpace)...])
        }
        return remark
    }

    /// Everything up to and including the last whitespace.
    static func textBeforeFragment(of remark: String) -> String {
        if let lastSpace = remark.lastIndex(where: { $0.isWhitespace }) {
            return String(remark[...lastSpace])
        }
        return ""
    }

    /// Splits a remark into countable words: whitespace-separated tokens with
    /// leading/trailing punctuation and symbols removed. Internal punctuation
    /// survives, so "joe's" stays intact. Words under 2 characters are ignored,
    /// and hashtags are left to the tag index so "#work" isn't also offered
    /// as the plain word "work".
    static func words(in remark: String) -> [String] {
        let trimSet = CharacterSet.punctuationCharacters.union(.symbols)
        return remark
            .split(whereSeparator: { $0.isWhitespace })
            .filter { !$0.hasPrefix("#") }
            .map { $0.trimmingCharacters(in: trimSet) }
            .filter { $0.count >= 2 }
    }
}

// MARK: - Category helpers

extension Category {
    /// Default name of the category the transfer flow creates for both legs.
    static let transferName = "Transfer"
    /// Default name of the category the Reconcile tool creates for "The Plug".
    static let reconciliationAdjustmentName = "Reconciliation Adjustment"

    /// Categories the app creates for its own bookkeeping. They're never
    /// offered as choices in the transaction form.
    var isSystemCategory: Bool { systemRole != nil }
}

// MARK: - TransactionStore API

extension TransactionStore {

    var remarkIndex: RemarkIndex {
        if let cached = remarkIndexCache { return cached }
        let systemIDs = Set(categories.filter { $0.isSystemCategory }.map { $0.id })
        let built = RemarkIndex(transactions: transactions, systemCategoryIDs: systemIDs)
        remarkIndexCache = built
        return built
    }

    func remarkSuggestions(for remark: String, type: TransactionType,
                           categoryID: UUID?, limit: Int = 3) -> [RemarkSuggestion] {
        remarkIndex.suggestions(for: remark, type: type, categoryID: categoryID, limit: limit)
    }

    /// Past remark WORDS containing `fragment`, prefix matches first, then by
    /// frequency and recency. Used by the bucket editor.
    func remarkWordSuggestions(completing fragment: String, limit: Int = 3) -> [String] {
        remarkIndex.wordSuggestions(completing: fragment, limit: limit)
    }

    func lastTransaction(withRemark remark: String, type: TransactionType) -> Transaction? {
        remarkIndex.lastTransaction(withRemark: remark, type: type)
    }

    /// Past hashtags completing `fragment` ("#wo" → "#work"), with the "#".
    func remarkTagSuggestions(completing fragment: String, limit: Int = 3) -> [String] {
        let body = fragment.hasPrefix("#") ? String(fragment.dropFirst()) : fragment
        return remarkIndex.tagSuggestions(completing: body, limit: limit).map(\.text)
    }

    /// Every distinct remark, tokenized, for the bucket editor's preview.
    func remarkCorpus() -> RemarkCorpus {
        RemarkCorpus(transactions: transactions,
                     plugCategoryIDs: systemCategoryIDs(for: .reconciliationAdjustment))
    }

    /// Up to `limit` categories for one-tap selection: the most used among
    /// the recent transactions of this type, then the rest alphabetically.
    /// Archived and system categories are never included.
    func suggestedCategories(for type: CategoryType, limit: Int = 5) -> [Category] {
        let eligible = categories.filter { $0.type == type && !$0.isArchived && !$0.isSystemCategory }
        let eligibleIDs = Set(eligible.map { $0.id })
        let txType: TransactionType = (type == .inflow) ? .inflow : .outflow

        var usage: [UUID: (count: Int, lastIndex: Int)] = [:]
        // Most recently entered first; the last 300 matching entries are
        // enough to reflect current habits.
        var seen = 0
        for index in transactions.indices.reversed() {
            if seen >= 300 { break }
            let tx = transactions[index]
            guard tx.type == txType, tx.linkedTransactionID == nil,
                  eligibleIDs.contains(tx.categoryID) else { continue }
            seen += 1
            let current = usage[tx.categoryID] ?? (0, index)
            usage[tx.categoryID] = (current.count + 1, max(current.lastIndex, index))
        }

        let used = eligible
            .filter { usage[$0.id] != nil }
            .sorted {
                let a = usage[$0.id]!, b = usage[$1.id]!
                if a.count != b.count { return a.count > b.count }
                return a.lastIndex > b.lastIndex
            }
        let unused = eligible
            .filter { usage[$0.id] == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Array((used + unused).prefix(limit))
    }

    /// Number of categories the form could offer for this type.
    func selectableCategoryCount(for type: CategoryType) -> Int {
        categories.filter { $0.type == type && !$0.isArchived && !$0.isSystemCategory }.count
    }

    /// The account used by the most recently entered transaction of this
    /// type (for transfers, the "From" side). Plugs are ignored. The form
    /// still checks the account is allowed before using it.
    func lastUsedSourceAccountID(for type: TransactionType) -> UUID? {
        let systemIDs = Set(categories.filter { $0.isSystemCategory }.map { $0.id })
        switch type {
        case .inflow, .outflow:
            return transactions.last {
                $0.type == type && $0.linkedTransactionID == nil && !systemIDs.contains($0.categoryID)
            }?.accountID
        case .transfer:
            return transactions.last { $0.linkedTransactionID != nil && $0.type == .outflow }?.accountID
        }
    }
}
