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
    @Published var tags: [Tag] = []
    @Published var templates: [TransactionTemplate] = []
    @Published var insightPresets: [InsightPreset] = []
    
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
            self.tags           = data.tags
            self.templates      = data.templates
            self.insightPresets = data.insightPresets
        } catch {
            // No data file for this book yet — start fresh with empty state.
            self.transactions   = []
            self.categories     = []
            self.tags           = []
            self.templates      = []
            self.insightPresets = []
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
                tags: tags,
                templates: templates,
                insightPresets: insightPresets
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
            tags: tags,
            templates: templates,
            insightPresets: insightPresets
        )
        Task {
            try? await StorageService.shared.save(data, to: transactionsFilename(for: bookID))
        }
    }
    
    /// Initializes default categories and tags on first launch.
    @MainActor
    func initializeDefaultsIfNeeded() {
        if categories.isEmpty {
            addCategory(name: "Food",        type: .outflow, emoji: "🍱")
            addCategory(name: "Housing",     type: .outflow, emoji: "🏠")
            addCategory(name: "Lifestyle",   type: .outflow, emoji: "🎨")
            addCategory(name: "Income",      type: .inflow,  emoji: "💰")
        }
        
        if tags.isEmpty {
            addTag(name: "Caffeine",   keywords: ["starbucks", "dunkin", "espresso"])
            addTag(name: "Subscriptions",  keywords: ["netflix", "spotify"])
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
                        tagIDs: [UUID],
                        amount: Decimal,
                        date: Date,
                        isOutlier: Bool = false) {
        let transaction = Transaction(id: id,
                                      linkedTransactionID: linkedTransactionID,
                                      type: type,
                                      accountID: accountID,
                                      categoryID: categoryID,
                                      tagIDs: tagIDs,
                                      amount: amount,
                                      date: date,
                                      isOutlier: isOutlier)
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
                partner.tagIDs    = transaction.tagIDs
                partner.isOutlier = transaction.isOutlier
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

    func removeTagFromTransactions(tagID: UUID) {
        for i in 0..<transactions.count {
            if transactions[i].tagIDs.contains(tagID) {
                transactions[i].tagIDs.removeAll { $0 == tagID }
            }
        }
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
                     tagIDs: [UUID] = [],
                     isOutlier: Bool = false,
                     transferTargetAccountID: UUID? = nil) {
        let template = TransactionTemplate(name: name,
                                           type: type,
                                           accountID: accountID,
                                           categoryID: categoryID,
                                           tagIDs: tagIDs,
                                           isOutlier: isOutlier,
                                           transferTargetAccountID: transferTargetAccountID)
        templates.append(template)
        save()
        updateReminders()
    }
    
    func updateTemplate(_ template: TransactionTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            save()
            updateReminders()
        }
    }

    func removeTemplate(_ template: TransactionTemplate) {
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
    // MARK: - Categories & Tags
    // =========================================================
    
    func addCategory(name: String, type: CategoryType, emoji: String) {
        let category = Category(name: name, type: type, emoji: emoji)
        categories.append(category)
        save()
    }

    func addTag(name: String, keywords: [String] = []) {
        let tag = Tag(name: name, keywords: keywords)
        tags.append(tag)
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
    
    func updateTag(id: UUID, name: String, keywords: [String]) {
        if let index = tags.firstIndex(where: { $0.id == id }) {
            tags[index].name     = name
            tags[index].keywords = keywords
            save()
        }
    }
    
    func setTagArchived(_ id: UUID, archived: Bool) {
        if let index = tags.firstIndex(where: { $0.id == id }) {
            tags[index].isArchived = archived
            save()
        }
    }

    func deleteTag(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
        save()
    }

    func transactions(for tag: Tag) -> [Transaction] {
        transactions.filter { $0.tagIDs.contains(tag.id) }
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

    func applyTags(_ tagIDs: Set<UUID>, toTransactionIDs transactionIDs: Set<UUID>) {
        for id in transactionIDs {
            if let index = transactions.firstIndex(where: { $0.id == id }) {
                let merged = Set(transactions[index].tagIDs).union(tagIDs)
                transactions[index].tagIDs = Array(merged)
            }
        }
        save()
    }

}
