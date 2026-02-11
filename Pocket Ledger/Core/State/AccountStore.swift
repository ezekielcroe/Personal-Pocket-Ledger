//
//  AccountStore.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 10/2/26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class AccountStore: ObservableObject {
    
    // MARK: - State
    
    @Published var accounts: [Account] = []
    @Published var accountGroups: [AccountGroup] = []
    
    // MARK: - Book Management State
    
    @Published var availableBooks: [BookMetadata] = []
    @Published var activeBook: BookMetadata?
    
    
    // =========================================================
    // MARK: - App Startup
    // =========================================================
    
    /// The single entry point called on app launch. It loads the book index,
    /// resolves which book should be active, then loads that book's data
    /// (both accounts and transactions) in the correct order.
    func loadBookIndex(transactionStore: TransactionStore) async {
        do {
            // 1. Try to load the existing book index from disk
            let index = try await StorageService.shared.load(BookIndex.self, from: "book_index.json")
            availableBooks = index.books
            
            // 2. Determine which book to open (last active, or first available)
            let bookToLoad: BookMetadata
            if let lastID = index.lastActiveBookID,
               let lastBook = index.books.first(where: { $0.id == lastID }) {
                bookToLoad = lastBook
            } else if let firstBook = index.books.first {
                bookToLoad = firstBook
            } else {
                // Index file exists but has no books (edge case) — create a default
                await createDefaultBook(transactionStore: transactionStore)
                return
            }
            
            // 3. Load data for that book
            await loadBookData(bookToLoad, transactionStore: transactionStore)
            
        } catch {
            // book_index.json doesn't exist yet — this is a fresh install
            await createDefaultBook(transactionStore: transactionStore)
        }
    }
    
    /// Creates the initial "Personal" book on first launch.
    private func createDefaultBook(transactionStore: TransactionStore) async {
        let defaultBook = BookMetadata(name: "Personal")
        availableBooks = [defaultBook]
        activeBook = defaultBook
        transactionStore.activeBook = defaultBook
        
        // Save the index so it exists next time
        saveBookIndex()
        
        // Initialize demo accounts and default categories/tags
        initializeDefaultsIfNeeded()
        transactionStore.initializeDefaultsIfNeeded()
        
        // Persist the initial data under the new book's filename
        save()
        transactionStore.save()
    }
    
    
    // =========================================================
    // MARK: - Book CRUD
    // =========================================================

    /// Creates a new empty book and immediately switches to it.
    func createBook(name: String, transactionStore: TransactionStore) {
        // 1. Save current book before leaving
        save()
        transactionStore.save()
        
        // 2. Create the new book
        let newBook = BookMetadata(name: name)
        availableBooks.append(newBook)
        
        // 3. Switch to it (clears current data, starts fresh)
        Task {
            await loadBookData(newBook, transactionStore: transactionStore)
        }
    }
    
    /// Switches to a different existing book, saving the current one first.
    func switchToBook(_ book: BookMetadata, transactionStore: TransactionStore) async {
        guard book.id != activeBook?.id else { return }
        
        // 1. Save current book before leaving
        save()
        transactionStore.save()
        
        // 2. Load the selected book
        await loadBookData(book, transactionStore: transactionStore)
    }
    
    /// Renames a book. Updates the active book reference if it's the one being renamed.
    func renameBook(_ book: BookMetadata, to newName: String) {
        guard let index = availableBooks.firstIndex(where: { $0.id == book.id }) else { return }
        
        availableBooks[index].name = newName
        
        // Keep the active book reference in sync if this is the current book
        if activeBook?.id == book.id {
            activeBook?.name = newName
        }
        
        saveBookIndex()
    }
    
    /// Permanently deletes a book and both of its data files. Cannot delete the active book.
    func deleteBook(_ book: BookMetadata, transactionStore: TransactionStore) {
        guard book.id != activeBook?.id else { return }
        
        // 1. Remove from the index
        availableBooks.removeAll { $0.id == book.id }
        saveBookIndex()
        
        // 2. Delete both data files from disk
        Task {
            try? await StorageService.shared.delete(filename: accountsFilename(for: book.id))
            try? await StorageService.shared.delete(filename: transactionsFilename(for: book.id))
        }
    }
    
    /// Erases all accounts and transactions in the current book, leaving the book itself intact.
    func resetActiveBook(transactionStore: TransactionStore) {
        accounts = []
        accountGroups = []
        transactionStore.transactions = []
        save()
        transactionStore.save()
    }
    
    // =========================================================
    // MARK: - Book Persistence (Private)
    // =========================================================
    
    /// Generates the accounts filename for a specific book.
    private func accountsFilename(for bookID: UUID) -> String {
        "accounts_\(bookID.uuidString).json"
    }
    
    /// Generates the transactions filename for a specific book.
    /// Exposed as internal so TransactionStore can use the same naming convention.
    func transactionsFilename(for bookID: UUID) -> String {
        "transactions_\(bookID.uuidString).json"
    }
    
    /// Saves the book index (list of all books + which is active) to disk.
    private func saveBookIndex() {
        let index = BookIndex(
            books: availableBooks,
            lastActiveBookID: activeBook?.id
        )
        Task {
            try? await StorageService.shared.save(index, to: "book_index.json")
        }
    }
    
    /// Core internal method: sets the active book in both stores, loads their data from disk.
    private func loadBookData(_ book: BookMetadata, transactionStore: TransactionStore) async {
        // 1. Mark book as active and update its lastOpened timestamp
        var updatedBook = book
        updatedBook.lastOpened = Date()
        activeBook = updatedBook
        transactionStore.activeBook = updatedBook
        
        // 2. Update the book in the index with the new timestamp
        if let index = availableBooks.firstIndex(where: { $0.id == book.id }) {
            availableBooks[index] = updatedBook
        }
        
        // 3. Save the updated index
        saveBookIndex()
        
        // 4. Load account data for this book
        await loadAccounts(for: updatedBook)
        
        // 5. Load transaction data for this book
        await transactionStore.loadTransactions(for: updatedBook)
    }
    
    /// Loads account and group data for a specific book. Initializes defaults if no data exists yet.
    private func loadAccounts(for book: BookMetadata) async {
        do {
            let data = try await StorageService.shared.load(
                SavedAccountData.self,
                from: accountsFilename(for: book.id)
            )
            self.accounts = data.accounts
            self.accountGroups = data.accountGroups
        } catch {
            // No data file for this book yet — start fresh
            self.accounts = []
            self.accountGroups = []
        }
    }
    
    func restoreFromBackup(url: URL, transactionStore: TransactionStore) async throws {
        let data = try await StorageService.shared.readSecureData(from: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(SavedData.self, from: data)
        
        accounts      = backup.accounts
        accountGroups = backup.accountGroups
        transactionStore.transactions = backup.transactions
        transactionStore.categories   = backup.categories
        transactionStore.tags         = backup.tags
        transactionStore.templates    = backup.templates
        
        save()
        transactionStore.save()
    }
    
    
    // =========================================================
    // MARK: - Account Persistence (Public)
    // =========================================================
    
    /// Saves the current account data to the active book's file.
    public func save() {
        guard let bookID = activeBook?.id else { return }
        let data = SavedAccountData(accounts: accounts, accountGroups: accountGroups)
        Task {
            try? await StorageService.shared.save(data, to: accountsFilename(for: bookID))
        }
    }
    
    // =========================================================
    // MARK: - Account CRUD
    // =========================================================

    func addAccount(name: String,
                    initialAmount: Decimal,
                    isCredit: Bool = false,
                    targetAmount: Decimal? = nil,
                    targetDate: Date? = nil,
                    paymentFrequency: PaymentFrequency? = nil) {
        let account = Account(
            name: name,
            initialAmount: initialAmount,
            isCredit: isCredit,
            targetAmount: targetAmount,
            targetDate: targetDate,
            paymentFrequency: paymentFrequency
        )
        accounts.append(account)
        save()
    }
    
    func addAccountGroup(name: String, memberIDs: [UUID]) {
        let group = AccountGroup(name: name, memberIDs: memberIDs)
        accountGroups.append(group)
        save()
    }

    func updateAccount(id: UUID,
                       name: String,
                       initialAmount: Decimal,
                       targetAmount: Decimal? = nil,
                       targetDate: Date? = nil,
                       paymentFrequency: PaymentFrequency? = nil) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].name = name
            accounts[index].initialAmount = initialAmount
            accounts[index].targetAmount = targetAmount
            accounts[index].targetDate = targetDate
            accounts[index].paymentFrequency = paymentFrequency
            save()
        }
    }

    func deleteAccount(_ account: Account) {
        // 1. Remove from physical list
        accounts.removeAll { $0.id == account.id }
        
        // 2. Scrub reference from virtual groups
        for i in 0..<accountGroups.count {
            accountGroups[i].memberIDs.removeAll { $0 == account.id }
        }
        
        save()
    }
    
    func updateAccountGroup(_ group: AccountGroup) {
        if let index = accountGroups.firstIndex(where: { $0.id == group.id }) {
            accountGroups[index] = group
            save()
        }
    }
    
    func deleteAccountGroup(_ group: AccountGroup) {
        if let index = accountGroups.firstIndex(where: { $0.id == group.id }) {
            accountGroups.remove(at: index)
            save()
        }
    }
    
    
    // =========================================================
    // MARK: - Account Balance
    // =========================================================
    
    func balance(for account: Account, transactions: [Transaction]) -> Decimal {
        FinancialCalculator.balance(for: account, in: transactions)
    }

    func groupBalance(_ group: AccountGroup, transactions: [Transaction]) -> Decimal {
        FinancialCalculator.groupBalance(
            group,
            in: accountGroups,
            accounts: accounts,
            transactions: transactions
        )
    }
    
    // =========================================================
    // MARK: - Archive Operations
    // =========================================================

    func archiveAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].archivedDate = Date()
            save()
        }
    }

    func unarchiveAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].archivedDate = nil
            save()
        }
    }
    
    /// Automatically unarchives an account when it appears in a new transaction.
    public func unarchiveAccountIfNeeded(id: UUID) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            if accounts[index].isArchived {
                accounts[index].archivedDate = nil
                save()
            }
        }
    }
    
    
    // =========================================================
    // MARK: - Group Operations
    // =========================================================
    
    /// Returns all members (accounts + groups) for a group.
    func members(for group: AccountGroup) -> [MemberType] {
        var result: [MemberType] = []
        
        for memberID in group.memberIDs {
            if let account = accounts.first(where: { $0.id == memberID }) {
                result.append(.account(account))
            } else if let childGroup = accountGroups.first(where: { $0.id == memberID }) {
                result.append(.group(childGroup))
            }
        }
        
        return result
    }
    
    /// Safely adds a member to a group (with cycle detection).
    func addMember(_ memberID: UUID, to groupID: UUID) throws {
        guard let index = accountGroups.firstIndex(where: { $0.id == groupID }) else {
            throw GroupError.groupNotFound
        }
        
        var group = accountGroups[index]
        
        // Check for cycles if adding a group
        if accountGroups.contains(where: { $0.id == memberID }) {
            if group.wouldCreateCycle(byAdding: memberID, in: accountGroups) {
                throw GroupError.wouldCreateCycle
            }
        }
        
        // Check for duplicates
        if group.memberIDs.contains(memberID) {
            throw GroupError.memberAlreadyExists
        }
        
        group.memberIDs.append(memberID)
        accountGroups[index] = group
        save()
    }
    
    /// Removes a member from a group.
    func removeMember(_ memberID: UUID, from groupID: UUID) {
        guard let index = accountGroups.firstIndex(where: { $0.id == groupID }) else { return }
        
        var group = accountGroups[index]
        group.memberIDs.removeAll { $0 == memberID }
        accountGroups[index] = group
        save()
    }
    
    /// Returns the depth of nesting for a group.
    func depth(of group: AccountGroup) -> Int {
        group.depth(in: accountGroups)
    }
    
    /// Returns all account IDs in a group (flattened, recursive).
    func allAccountIDs(in group: AccountGroup) -> [UUID] {
        Array(group.allAccountIDs(in: accountGroups, accounts: accounts))
    }
    
    /// Validates group structure integrity.
    func validateGroupStructure() -> [GroupValidationError] {
        var errors: [GroupValidationError] = []
        
        for group in accountGroups {
            for memberID in group.memberIDs {
                if accountGroups.contains(where: { $0.id == memberID }) {
                    if group.wouldCreateCycle(byAdding: memberID, in: accountGroups) {
                        errors.append(.cycle(groupName: group.name))
                    }
                }
                
                let isAccount = accounts.contains(where: { $0.id == memberID })
                let isGroup = accountGroups.contains(where: { $0.id == memberID })
                
                if !isAccount && !isGroup {
                    errors.append(.orphanedMember(groupName: group.name, memberID: memberID))
                }
            }
        }
        
        return errors
    }
    
    
    // =========================================================
    // MARK: - Reconciliation
    // =========================================================
    
    func markAccountAsReconciled(_ accountID: UUID) {
        if let index = accounts.firstIndex(where: { $0.id == accountID }) {
            accounts[index].lastReconciledDate = Date()
            save()
        }
    }
    
    
    // =========================================================
    // MARK: - Default Data
    // =========================================================

    @MainActor
    func initializeDefaultsIfNeeded() {
        guard accounts.isEmpty else { return }
        
        addAccount(name: "Main Checking", initialAmount: 2500.00, isCredit: false)
        addAccount(name: "Daily Driver Card", initialAmount: 0.00, isCredit: true, targetAmount: 2000.00)
        addAccount(name: "Laptop Fund", initialAmount: 450.00, isCredit: false, targetAmount: 2000.00)
        addAccount(name: "Student Loan", initialAmount: 15000.00, isCredit: true, targetAmount: 0.00)
    }
}


// =========================================================
// MARK: - Supporting Types
// =========================================================

enum MemberType: Sendable {
    case account(Account)
    case group(AccountGroup)
    
    var id: UUID {
        switch self {
        case .account(let account): return account.id
        case .group(let group):     return group.id
        }
    }
    
    var name: String {
        switch self {
        case .account(let account): return account.name
        case .group(let group):     return group.name
        }
    }
}

enum GroupError: LocalizedError {
    case groupNotFound
    case wouldCreateCycle
    case memberAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .groupNotFound:
            return "Group not found"
        case .wouldCreateCycle:
            return "Adding this group would create a circular reference"
        case .memberAlreadyExists:
            return "This member is already in the group"
        }
    }
}

enum GroupValidationError: Identifiable {
    case cycle(groupName: String)
    case orphanedMember(groupName: String, memberID: UUID)
    
    var id: String {
        switch self {
        case .cycle(let name):              return "cycle-\(name)"
        case .orphanedMember(let name, let id): return "orphan-\(name)-\(id)"
        }
    }
    
    var description: String {
        switch self {
        case .cycle(let name):
            return "Circular reference detected in group: \(name)"
        case .orphanedMember(let name, let id):
            return "Orphaned member in group '\(name)': \(id)"
        }
    }
}
