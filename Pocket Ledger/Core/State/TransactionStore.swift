//
//  TransactionStore.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 10/2/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TransactionStore: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var categories: [Category] = []
    @Published var templates: [TransactionTemplate] = []
    @Published var insightPresets: [InsightPreset] = []
    @Published var remarkBuckets: [RemarkBucket] = []
    
    /// Set by AccountStore during book switches. Used to derive the correct save filename.
    @Published var activeBook: BookMetadata?
    
    // MARK: - Cross-Store Reference
    // Weak to avoid a retain cycle. Set by PocketLedgerApp on startup.
    weak var accountStore: AccountStore?
    
    // MARK: - Debounce
    private var saveTask: Task<Void, Never>?
    
    
    // =========================================================
    // MARK: - Persistence
    // =========================================================
    
    func transactions(for account: Account) -> [Transaction] {
        transactions.filter { $0.accountID == account.id }
    }
    
    private func transactionsFilename(for bookID: UUID) -> String {
        "transactions_\(bookID.uuidString).json"
    }
    
    func loadTransactions(for book: BookMetadata) async {
        do {
            let data = try await StorageService.shared.load(
                SavedTransactionData.self,
                from: transactionsFilename(for: book.id)
            )
            self.transactions   = data.transactions
            self.categories     = data.categories
            self.templates      = data.templates
            self.insightPresets = data.insightPresets
            self.remarkBuckets  = data.remarkBuckets
            
            // One-time migration: fold tag names from pre-remark data
            // into transaction and template remarks.
            migrateLegacyTags(data.legacyTags)
        } catch {
            // No data file for this book yet — start fresh with empty state.
            self.transactions   = []
            self.categories     = []
            self.templates      = []
            self.insightPresets = []
            self.remarkBuckets  = []
        }
        
        // Recompute balances once after all data is loaded for this book.
        accountStore?.recomputeBalances(using: self.transactions)
        
        if let book = activeBook {
            NotificationManager.shared.updateReminders(for: templates, bookID: book.id)
        }
    }
    
    /// Debounced save: coalesces rapid successive calls into a single disk write.
    /// Multiple calls within 500ms will cancel the previous pending write and restart the timer.
    public func save() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard !Task.isCancelled else { return }
            guard let bookID = activeBook?.id else { return }
            let data = SavedTransactionData(
                transactions: transactions,
                categories: categories,
                templates: templates,
                insightPresets: insightPresets,
                remarkBuckets: remarkBuckets
            )
            try? await StorageService.shared.save(data, to: transactionsFilename(for: bookID))
        }
    }
    
    /// Bypasses the debounce and writes to disk immediately.
    /// Called when the app is backgrounded to ensure no data is lost.
    public func saveImmediately() {
        saveTask?.cancel()
        guard let bookID = activeBook?.id else { return }
        let data = SavedTransactionData(
            transactions: transactions,
            categories: categories,
            templates: templates,
            insightPresets: insightPresets,
            remarkBuckets: remarkBuckets
        )
        Task {
            try? await StorageService.shared.save(data, to: transactionsFilename(for: bookID))
        }
    }
    
    /// Initializes default categories on first launch.
    @MainActor
    func initializeDefaultsIfNeeded() {
        if categories.isEmpty {
            addCategory(name: "Food",        type: .outflow, emoji: "🍱")
            addCategory(name: "Housing",     type: .outflow, emoji: "🏠")
            addCategory(name: "Lifestyle",   type: .outflow, emoji: "🎨")
            addCategory(name: "Income",      type: .inflow,  emoji: "💰")
        }
    }

    
    // =========================================================
    // MARK: - Transaction CRUD
    // =========================================================
    
    func addTransaction(id: UUID? = nil,
                        linkedTransactionID: UUID? = nil,
                        type: TransactionType,
                        accountID: UUID,
                        categoryID: UUID,
                        amount: Decimal,
                        date: Date,
                        isOutlier: Bool = false,
                        remark: String = "") {
        let transaction = Transaction(id: id,
                                      linkedTransactionID: linkedTransactionID,
                                      type: type,
                                      accountID: accountID,
                                      categoryID: categoryID,
                                      amount: amount,
                                      date: date,
                                      isOutlier: isOutlier,
                                      remark: remark)
        transactions.append(transaction)
        accountStore?.recomputeBalances(using: transactions)
        save()
    }
    
    func updateTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            
            // Sync logic: update partner if linked
            if let linkedID = transaction.linkedTransactionID,
               let linkedIndex = transactions.firstIndex(where: { $0.id == linkedID }) {
                
                var partner = transactions[linkedIndex]
                partner.amount    = transaction.amount
                partner.date      = transaction.date
                partner.isOutlier = transaction.isOutlier
                partner.remark    = transaction.remark
                transactions[linkedIndex] = partner
            }
            
            accountStore?.recomputeBalances(using: transactions)
            save()
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions.remove(at: index)
        }
        
        if let linkedID = transaction.linkedTransactionID,
           let linkedIndex = transactions.firstIndex(where: { $0.id == linkedID }) {
            transactions.remove(at: linkedIndex)
        }
        
        accountStore?.recomputeBalances(using: transactions)
        save()
    }

    
    // =========================================================
    // MARK: - Legacy Tag Migration
    // =========================================================
    
    /// Folds tag names from pre-remark data into remarks, then clears the
    /// legacy IDs. Runs once per book: after migration nothing re-encodes
    /// tags or tag IDs, so subsequent loads find nothing to migrate.
    func migrateLegacyTags(_ legacyTags: [LegacyTag]) {
        let hasWork = transactions.contains { !$0.legacyTagIDs.isEmpty }
                   || templates.contains { !$0.legacyTagIDs.isEmpty }
        guard hasWork else { return }
        
        let names = Dictionary(legacyTags.map { ($0.id, $0.name) },
                               uniquingKeysWith: { first, _ in first })
        
        func merged(_ remark: String, ids: [UUID]) -> String {
            let tagNames = ids.compactMap { names[$0] }
            guard !tagNames.isEmpty else { return remark }
            let joined = tagNames.joined(separator: ", ")
            return remark.isEmpty ? joined : "\(remark) (\(joined))"
        }
        
        for i in transactions.indices where !transactions[i].legacyTagIDs.isEmpty {
            transactions[i].remark = merged(transactions[i].remark,
                                            ids: transactions[i].legacyTagIDs)
            transactions[i].legacyTagIDs = []
        }
        
        for i in templates.indices where !templates[i].legacyTagIDs.isEmpty {
            templates[i].remark = merged(templates[i].remark,
                                         ids: templates[i].legacyTagIDs)
            templates[i].legacyTagIDs = []
        }
        
        save()
    }
    
    
    // =========================================================
    // MARK: - Remark Autocomplete
    // =========================================================
    
    /// Returns past remark WORDS that complete `fragment` (the word currently
    /// being typed), ranked by how often each word appears across all remarks
    /// and then by how recently. An empty fragment returns the overall
    /// most-used words. Counting is case-insensitive — "starbucks" and
    /// "Starbucks" are one word — and the most recently used casing wins.
    /// Surrounding punctuation is stripped, so "(Caffeine)" counts as
    /// "Caffeine"; words shorter than 2 characters are ignored.
    func remarkWordSuggestions(completing fragment: String, limit: Int = 3) -> [String] {
        var usage: [String: (text: String, count: Int, lastUsed: Date)] = [:]
        
        for tx in transactions {
            for word in Self.remarkWords(in: tx.remark) {
                let key = word.lowercased()
                if var entry = usage[key] {
                    entry.count += 1
                    if tx.date > entry.lastUsed {
                        entry.lastUsed = tx.date
                        entry.text = word
                    }
                    usage[key] = entry
                } else {
                    usage[key] = (word, 1, tx.date)
                }
            }
        }
        
        let q = fragment.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidates = usage.values
            .filter { q.isEmpty || $0.text.lowercased().contains(q) }
            .filter { $0.text.lowercased() != q } // don't suggest what's already typed
        
        return candidates
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.lastUsed > $1.lastUsed
            }
            .prefix(limit)
            .map { $0.text }
    }
    
    /// Splits a remark into countable words: whitespace-separated tokens with
    /// leading/trailing punctuation and symbols removed. Internal punctuation
    /// survives, so "joe's" stays intact.
    private static func remarkWords(in remark: String) -> [String] {
        let trimSet = CharacterSet.punctuationCharacters.union(.symbols)
        return remark
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: trimSet) }
            .filter { $0.count >= 2 }
    }
    
    
    // =========================================================
    // MARK: - Remark Buckets
    // =========================================================
    
    /// Adds a new bucket or updates an existing one (matched by id).
    func saveBucket(_ bucket: RemarkBucket) {
        if let index = remarkBuckets.firstIndex(where: { $0.id == bucket.id }) {
            remarkBuckets[index] = bucket
        } else {
            remarkBuckets.append(bucket)
        }
        save()
    }
    
    func deleteBucket(_ bucket: RemarkBucket) {
        remarkBuckets.removeAll { $0.id == bucket.id }
        save()
    }
    
    
    // =========================================================
    // MARK: - Insight Presets
    // =========================================================
    
    func savePreset(_ preset: InsightPreset) {
        if let index = insightPresets.firstIndex(where: { $0.id == preset.id }) {
            insightPresets[index] = preset
        } else {
            insightPresets.append(preset)
        }
        save()
    }
    
    func deletePreset(_ preset: InsightPreset) {
        insightPresets.removeAll { $0.id == preset.id }
        save()
    }
    
    
    // =========================================================
    // MARK: - Templates
    // =========================================================

        func addTemplate(name: String,
                         type: TransactionType,
                         accountID: UUID? = nil,
                         categoryID: UUID? = nil,
                         isOutlier: Bool = false,
                         transferTargetAccountID: UUID? = nil,
                         remark: String = "") {
            let template = TransactionTemplate(name: name,
                                               type: type,
                                               accountID: accountID,
                                               categoryID: categoryID,
                                               isOutlier: isOutlier,
                                               transferTargetAccountID: transferTargetAccountID,
                                               remark: remark)
            templates.append(template)
            save()
            updateReminders()
        }
        
        func updateTemplate(_ template: TransactionTemplate) {
            if let index = templates.firstIndex(where: { $0.id == template.id }) {
                let oldTemplate = templates[index]
                templates[index] = template
                
                // If a reminder was removed, immediately cancel that specific notification
                // as a direct safety net (don't rely solely on the batch update).
                if oldTemplate.reminderSchedule != nil && template.reminderSchedule == nil {
                    if let book = activeBook {
                        NotificationManager.shared.removeReminder(for: template.id, bookID: book.id)
                    }
                }
                
                save()
                updateReminders()
            }
        }

        func removeTemplate(_ template: TransactionTemplate) {
            // Immediately cancel the notification for this specific template first
            if template.reminderSchedule != nil, let book = activeBook {
                NotificationManager.shared.removeReminder(for: template.id, bookID: book.id)
            }
            templates.removeAll { $0.id == template.id }
            save()
            updateReminders()
        }
        
        private func updateReminders() {
            if let book = activeBook {
                NotificationManager.shared.updateReminders(for: templates, bookID: book.id)
            }
        }
    
    
    // =========================================================
    // MARK: - Categories
    // =========================================================
    
    func addCategory(name: String, type: CategoryType, emoji: String) {
        let category = Category(name: name, type: type, emoji: emoji)
        categories.append(category)
        save()
    }

    func updateCategory(id: UUID, name: String, type: CategoryType, emoji: String) {
        if let index = categories.firstIndex(where: { $0.id == id }) {
            categories[index].name  = name
            categories[index].type  = type
            categories[index].emoji = emoji
            save()
        }
    }
    
    func deleteTransactions(withIDs ids: Set<UUID>) {
        var allIDs = ids
        for id in ids {
            if let linked = transactions.first(where: { $0.id == id })?.linkedTransactionID {
                allIDs.insert(linked)
            }
        }
        transactions.removeAll { allIDs.contains($0.id) }
        accountStore?.recomputeBalances(using: transactions)
        save()
    }

}
