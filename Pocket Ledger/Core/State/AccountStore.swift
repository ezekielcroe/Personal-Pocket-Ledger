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
    @Published var isLoaded: Bool = false
    
    // MARK: - Book Management State
    @Published var availableBooks: [BookMetadata] = []
    @Published var activeBook: BookMetadata?
    
    // MARK: - Balance Cache
    // Pre-computed balances keyed by account/group ID.
    // Updated by recomputeBalances(using:) whenever accounts or transactions change.
    @Published var balances: [UUID: Decimal] = [:]
    @Published var groupBalances: [UUID: Decimal] = [:]
    
    // MARK: - Cross-Store Reference
    // Weak to avoid a retain cycle. Set by PocketLedgerApp on startup.
    weak var transactionStore: TransactionStore?
    
    // MARK: - Debounce
    private var saveTask: Task<Void, Never>?
    
    
    // =========================================================
    // MARK: - App Startup
    // =========================================================
    
    func loadBookIndex(transactionStore: TransactionStore) async {
        do {
            let index = try await StorageService.shared.load(BookIndex.self, from: "book_index.json")
            availableBooks = index.books
            
            let bookToLoad: BookMetadata
            if let lastID = index.lastActiveBookID,
               let lastBook = index.books.first(where: { $0.id == lastID }) {
                bookToLoad = lastBook
            } else if let firstBook = index.books.first {
                bookToLoad = firstBook
            } else {
                await createDefaultBook(transactionStore: transactionStore)
                return
            }
            
            await loadBookData(bookToLoad, transactionStore: transactionStore)
            
        } catch {
            await createDefaultBook(transactionStore: transactionStore)
        }
    }
    
    private func createDefaultBook(transactionStore: TransactionStore) async {
        let defaultBook = BookMetadata(name: "Personal")
        availableBooks = [defaultBook]
        activeBook = defaultBook
        transactionStore.activeBook = defaultBook
        
        saveBookIndex()
        
        initializeDefaultsIfNeeded()
        transactionStore.initializeDefaultsIfNeeded()
        
        save()
        transactionStore.save()
    }
    
    
    // =========================================================
    // MARK: - Book CRUD
    // =========================================================

    func createBook(name: String, transactionStore: TransactionStore) {
        save()
        transactionStore.save()
        
        let newBook = BookMetadata(name: name)
        availableBooks.append(newBook)
        
        Task {
            await loadBookData(newBook, transactionStore: transactionStore)
        }
    }
    
    func switchToBook(_ book: BookMetadata, transactionStore: TransactionStore) async {
        guard book.id != activeBook?.id else { return }
        
        save()
        transactionStore.save()
        
        await loadBookData(book, transactionStore: transactionStore)
    }
    
    func renameBook(_ book: BookMetadata, to newName: String) {
        guard let index = availableBooks.firstIndex(where: { $0.id == book.id }) else { return }
        
        availableBooks[index].name = newName
        
        if activeBook?.id == book.id {
            activeBook?.name = newName
        }
        
        saveBookIndex()
    }
    
    func deleteBook(_ book: BookMetadata, transactionStore: TransactionStore) {
        guard book.id != activeBook?.id else { return }
        
        availableBooks.removeAll { $0.id == book.id }
        saveBookIndex()
        
        Task {
            try? await StorageService.shared.delete(filename: accountsFilename(for: book.id))
            try? await StorageService.shared.delete(filename: transactionsFilename(for: book.id))
        }
    }
    
    func resetActiveBook(transactionStore: TransactionStore) {
        accounts = []
        accountGroups = []
        transactionStore.transactions = []
        recomputeBalances(using: [])
        save()
        transactionStore.save()
    }
    
    // =========================================================
    // MARK: - Book Persistence (Private)
    // =========================================================
    
    private func accountsFilename(for bookID: UUID) -> String {
        "accounts_\(bookID.uuidString).json"
    }
    
    func transactionsFilename(for bookID: UUID) -> String {
        "transactions_\(bookID.uuidString).json"
    }
    
    private func saveBookIndex() {
        let index = BookIndex(
            books: availableBooks,
            lastActiveBookID: activeBook?.id
        )
        Task {
            try? await StorageService.shared.save(index, to: "book_index.json")
        }
    }
    
    private func loadBookData(_ book: BookMetadata, transactionStore: TransactionStore) async {
        var updatedBook = book
        updatedBook.lastOpened = Date()
        activeBook = updatedBook
        transactionStore.activeBook = updatedBook
        
        if let index = availableBooks.firstIndex(where: { $0.id == book.id }) {
            availableBooks[index] = updatedBook
        }
        
        saveBookIndex()
        
        await loadAccounts(for: updatedBook)
        
        // Transactions load next; recomputeBalances is called at the end of loadTransactions.
        await transactionStore.loadTransactions(for: updatedBook)
        
        isLoaded = true 
    }
    
    private func loadAccounts(for book: BookMetadata) async {
        do {
            let data = try await StorageService.shared.load(
                SavedAccountData.self,
                from: accountsFilename(for: book.id)
            )
            self.accounts = data.accounts
            self.accountGroups = data.accountGroups
        } catch {
            self.accounts = []
            self.accountGroups = []
        }
        // Balance recompute intentionally deferred: happens after transactions load.
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
        
        recomputeBalances(using: backup.transactions)
        save()
        transactionStore.save()
    }
    
    
    // =========================================================
    // MARK: - Account Persistence (Public)
    // =========================================================
    
    /// Debounced save: coalesces rapid successive calls into a single disk write.
    /// Multiple calls within 500ms will cancel the previous pending write and restart the timer.
    public func save() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard !Task.isCancelled else { return }
            guard let bookID = activeBook?.id else { return }
            let data = SavedAccountData(accounts: accounts, accountGroups: accountGroups)
            try? await StorageService.shared.save(data, to: accountsFilename(for: bookID))
        }
    }
    
    /// Bypasses the debounce and writes to disk immediately.
    /// Called when the app is backgrounded to ensure no data is lost.
    public func saveImmediately() {
        saveTask?.cancel()
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
        recomputeBalances(using: transactionStore?.transactions ?? [])
        save()
    }
    
    func addAccountGroup(name: String, memberIDs: [UUID]) {
        let group = AccountGroup(name: name, memberIDs: memberIDs)
        accountGroups.append(group)
        recomputeBalances(using: transactionStore?.transactions ?? [])
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
            recomputeBalances(using: transactionStore?.transactions ?? [])
            save()
        }
    }

    func deleteAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        
        for i in 0..<accountGroups.count {
            accountGroups[i].memberIDs.removeAll { $0 == account.id }
        }
        
        recomputeBalances(using: transactionStore?.transactions ?? [])
        save()
    }
    
    func updateAccountGroup(_ group: AccountGroup) {
        if let index = accountGroups.firstIndex(where: { $0.id == group.id }) {
            accountGroups[index] = group
            recomputeBalances(using: transactionStore?.transactions ?? [])
            save()
        }
    }
    
    func deleteAccountGroup(_ group: AccountGroup) {
        if let index = accountGroups.firstIndex(where: { $0.id == group.id }) {
            accountGroups.remove(at: index)
            recomputeBalances(using: transactionStore?.transactions ?? [])
            save()
        }
    }
    
    
    // =========================================================
    // MARK: - Account Balance
    // =========================================================
    
    /// Direct calculation — retained for use in detail views and reconciliation where
    /// the full transaction list is already available at the call site.
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
    
    /// Recomputes balances for all accounts and groups from scratch.
    /// Called whenever accounts change or transactions are loaded/mutated.
    func recomputeBalances(using transactions: [Transaction]) {
        var newBalances: [UUID: Decimal] = [:]
        for account in accounts {
            newBalances[account.id] = FinancialCalculator.balance(for: account, in: transactions)
        }
        balances = newBalances
        
        var newGroupBalances: [UUID: Decimal] = [:]
        for group in accountGroups {
            newGroupBalances[group.id] = FinancialCalculator.groupBalance(
                group, in: accountGroups, accounts: accounts, transactions: transactions
            )
        }
        groupBalances = newGroupBalances
    }
    
    
    // =========================================================
    // MARK: - Archive Operations
    // =========================================================

    func archiveAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].archivedDate = Date()
            recomputeBalances(using: transactionStore?.transactions ?? [])
            save()
        }
    }

    func unarchiveAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].archivedDate = nil
            recomputeBalances(using: transactionStore?.transactions ?? [])
            save()
        }
    }
    
    public func unarchiveAccountIfNeeded(id: UUID) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            if accounts[index].isArchived {
                accounts[index].archivedDate = nil
                recomputeBalances(using: transactionStore?.transactions ?? [])
                save()
            }
        }
    }
    
    
    // =========================================================
    // MARK: - Group Operations
    // =========================================================
    
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
    
    func addMember(_ memberID: UUID, to groupID: UUID) throws {
        guard let index = accountGroups.firstIndex(where: { $0.id == groupID }) else {
            throw GroupError.groupNotFound
        }
        
        var group = accountGroups[index]
        
        if accountGroups.contains(where: { $0.id == memberID }) {
            if group.wouldCreateCycle(byAdding: memberID, in: accountGroups) {
                throw GroupError.wouldCreateCycle
            }
        }
        
        if group.memberIDs.contains(memberID) {
            throw GroupError.memberAlreadyExists
        }
        
        group.memberIDs.append(memberID)
        accountGroups[index] = group
        recomputeBalances(using: transactionStore?.transactions ?? [])
        save()
    }
    
    func removeMember(_ memberID: UUID, from groupID: UUID) {
        guard let index = accountGroups.firstIndex(where: { $0.id == groupID }) else { return }
        
        var group = accountGroups[index]
        group.memberIDs.removeAll { $0 == memberID }
        accountGroups[index] = group
        recomputeBalances(using: transactionStore?.transactions ?? [])
        save()
    }
    
    func depth(of group: AccountGroup) -> Int {
        group.depth(in: accountGroups)
    }
    
    func allAccountIDs(in group: AccountGroup) -> [UUID] {
        Array(group.allAccountIDs(in: accountGroups, accounts: accounts))
    }
    
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
