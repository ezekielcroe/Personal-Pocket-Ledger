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
    
    
    // =========================================================
    // MARK: - Persistence
    // =========================================================
    
    func transactions(for account: Account) -> [Transaction] {
        transactions.filter { $0.accountID == account.id }
    }
    
    /// The transactions filename for a specific book.
    /// Kept in sync with AccountStore.transactionsFilename(for:).
    private func transactionsFilename(for bookID: UUID) -> String {
        "transactions_\(bookID.uuidString).json"
    }
    
    /// Called by AccountStore when switching to or loading a book.
    /// Loads transaction data scoped to that book's file.
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
            // Categories and tags are NOT reset here so a new book can inherit
            // them from whatever was previously loaded, or you can choose to
            // clear them too by uncommenting the lines below.
            self.transactions   = []
            // self.categories  = []
            // self.tags        = []
            // self.templates   = []
            // self.insightPresets = []
        }
    }
    
    /// Saves all transaction data to the active book's file.
    public func save() {
        guard let bookID = activeBook?.id else { return }
        let data = SavedTransactionData(
            transactions: transactions,
            categories: categories,
            tags: tags,
            templates: templates,
            insightPresets: insightPresets,
            reminderTime: nil
        )
        Task {
            try? await StorageService.shared.save(data, to: transactionsFilename(for: bookID))
        }
    }
    
    /// Initializes default categories and tags on first launch.
    @MainActor
    func initializeDefaultsIfNeeded() {
        if categories.isEmpty {
            addCategory(name: "Sustenance",  type: .outflow, emoji: "🍱")
            addCategory(name: "Housing",     type: .outflow, emoji: "🏠")
            addCategory(name: "Lifestyle",   type: .outflow, emoji: "🎨")
            addCategory(name: "Income",      type: .inflow,  emoji: "💰")
        }
        
        if tags.isEmpty {
            addTag(name: "#Caffeine",   keywords: ["starbucks", "dunkin", "espresso"])
            addTag(name: "#Recurring",  keywords: ["netflix", "spotify"])
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
            
            save()
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        // 1. Remove the target transaction
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions.remove(at: index)
        }
        
        // 2. Remove the linked partner if it exists
        if let linkedID = transaction.linkedTransactionID,
           let linkedIndex = transactions.firstIndex(where: { $0.id == linkedID }) {
            transactions.remove(at: linkedIndex)
        }
        
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
    
    // Used by ManageTagsView
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

    // Used by TagDetailView
    func transactions(for tag: Tag) -> [Transaction] {
        transactions.filter { $0.tagIDs.contains(tag.id) }
    }

    // Used by TransactionListView (bulk delete in edit mode)
    func deleteTransactions(withIDs ids: Set<UUID>) {
        // Include linked partners in deletion
        var allIDs = ids
        for id in ids {
            if let linked = transactions.first(where: { $0.id == id })?.linkedTransactionID {
                allIDs.insert(linked)
            }
        }
        transactions.removeAll { allIDs.contains($0.id) }
        save()
    }

    // Used by TransactionListView (batch tagging in edit mode)
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
