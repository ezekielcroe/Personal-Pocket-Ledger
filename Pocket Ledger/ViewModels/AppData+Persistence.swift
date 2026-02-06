import Foundation
import Combine
@preconcurrency import UserNotifications

extension AppData {
    
    // MARK: - File Paths
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    var indexURL: URL {
        documentsDirectory.appendingPathComponent("book_index.json")
    }
    
    func dataURL(for book: BookMetadata) -> URL {
        documentsDirectory.appendingPathComponent(book.fileName)
    }
    
    // MARK: - Index Operations

    func saveIndex() {
        let index = BookIndex(books: availableBooks, lastActiveBookID: activeBook?.id)
        
        Task {
            do {
                // 1. Encode on Main Actor
                let data = try JSONEncoder().encode(index)
                // 2. Write on Background Actor
                try await storage.write(data, to: indexURL)
            } catch {
                print("Failed to save book index: \(error.localizedDescription)")
            }
        }
    }

    func loadIndex() async {
        do {
            guard let data = try await storage.read(from: indexURL) else {
                await createDefaultBook()
                return
            }
            let index = try JSONDecoder().decode(BookIndex.self, from: data)
            self.availableBooks = index.books
            
            if let lastID = index.lastActiveBookID,
               let match = index.books.first(where: { $0.id == lastID }) {
                await loadBook(match)
            } else if let firstBook = index.books.first {
                await loadBook(firstBook)
            } else {
                await createDefaultBook()
            }
        } catch {
            await createDefaultBook()
        }
    }

    func createDefaultBook() async {
        let defaultBook = BookMetadata(name: "My Ledger")
        self.availableBooks = [defaultBook]
        saveIndex()
        await loadBook(defaultBook)
    }

    // MARK: - Book Loading & Saving

    func loadBook(_ book: BookMetadata) async {
        self.activeBook = book
        let url = dataURL(for: book)
        
        if let index = availableBooks.firstIndex(where: { $0.id == book.id }) {
            availableBooks[index].lastOpened = Date()
            saveIndex()
        }
        
        do {
            guard let data = try await storage.read(from: url) else {
                resetToEmpty()
                await initializeDefaultsIfNeeded()
                return
            }
            let decoded = try JSONDecoder().decode(SavedData.self, from: data)
            
            self.accounts = decoded.accounts
            self.accountGroups = decoded.accountGroups ?? []
            self.categories = decoded.categories
            self.tags = decoded.tags
            self.transactions = decoded.transactions
            self.templates = decoded.templates ?? []
            self.insightPresets = decoded.insightPresets ?? []
            self.reminderTime = decoded.reminderTime ?? DateComponents(hour: 21, minute: 0)
            updateReminders()
            
        } catch {
            print("Error decoding book data: \(error.localizedDescription)")
            resetToEmpty()
            await initializeDefaultsIfNeeded()
        }
    }

    func save() {
        guard let currentBook = activeBook else { return }
        let url = dataURL(for: currentBook)
        
        let snapshot = SavedData(
            accounts: accounts,
            accountGroups: accountGroups,
            categories: categories,
            tags: tags,
            transactions: transactions,
            templates: templates,
            reminderTime: reminderTime,
            insightPresets: insightPresets
        )
        
        Task {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try await storage.write(data, to: url)
            } catch {
                print("Error saving data: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Data Management

    func resetAllData() {
        resetToEmpty()
        save()
        Task { await initializeDefaultsIfNeeded() }
    }
    
    func resetToEmpty() {
        accounts = []
        accountGroups = []
        categories = []
        tags = []
        transactions = []
        templates = []
        insightPresets = []
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func restoreFromBackup(url: URL) throws {
        Task {
            do {
                let data = try await storage.readSecureData(from: url)
                let decoded = try JSONDecoder().decode(SavedData.self, from: data)
                
                self.accounts = decoded.accounts
                self.accountGroups = decoded.accountGroups ?? []
                self.categories = decoded.categories
                self.tags = decoded.tags
                self.transactions = decoded.transactions
                self.templates = decoded.templates ?? []
                self.insightPresets = decoded.insightPresets ?? []
                self.reminderTime = decoded.reminderTime ?? DateComponents(hour: 21, minute: 0)
                
                self.save()
                self.updateReminders()
            } catch {
                print("Restore failed: \(error)")
            }
        }
    }
    
    @MainActor
    func initializeDefaultsIfNeeded() async {
        if accounts.isEmpty {
            addAccount(name: "Cash", initialAmount: 0.0)
            addAccount(name: "Bank", initialAmount: 0.0)
        }
        
        if categories.isEmpty {
            addCategory(name: "Food", type: .outflow, emoji: "🍽")
            addCategory(name: "Housing", type: .outflow, emoji: "🏠")
            addCategory(name: "Transportation", type: .outflow, emoji: "🚗")
            addCategory(name: "Utilities", type: .outflow, emoji: "💡")
            addCategory(name: "Entertainment", type: .outflow, emoji: "🎮")
            addCategory(name: "Shopping", type: .outflow, emoji: "🛍")
            addCategory(name: "Health", type: .outflow, emoji: "💊")
            addCategory(name: "Gifts", type: .outflow, emoji: "🎁")
            addCategory(name: "Other", type: .outflow, emoji: "📦")
            addCategory(name: "Salary", type: .inflow, emoji: "💼")
            addCategory(name: "Bonus", type: .inflow, emoji: "💰")
            addCategory(name: "Other Income", type: .inflow, emoji: "📥")
        }
        
        if tags.isEmpty {
            addTag(name: "Mandatory")
            addTag(name: "Discretionary")
        }
    }
}
