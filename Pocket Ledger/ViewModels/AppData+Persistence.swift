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
        
        // MARK: - 1. Accounts (The Four Pillars)
        // We create one of each type to teach the different behaviors.
        if accounts.isEmpty {
            // A. DEBIT: The Standard Hub
            addAccount(name: "Main Checking", initialAmount: 2500.00, isCredit: false)
            
            // B. BUDGET (Credit): The "Limit is Budget" Lesson
            // We set a 2000 target. The UI will show this as "Available Capacity".
            addAccount(name: "Daily Driver Card", initialAmount: 0.0, isCredit: true, targetAmount: 2000.0)
            
            // C. GOAL: The "Progress Bar" Lesson
            // A savings goal with a target amount.
            addAccount(name: "Laptop Fund", initialAmount: 450.00, isCredit: false, targetAmount: 2000.0)
            
            // D. DEBT: The "Black Hole" Lesson
            // A debt account where you can only transfer IN (to pay off).
            addAccount(name: "Student Loan", initialAmount: 15000.00, isCredit: true, targetAmount: 0.0)
        }
        
        // MARK: - 2. Categories (Broad Philosophy)
        // We use broad categories to prevent decision fatigue.
        if categories.isEmpty {
            addCategory(name: "Sustenance", type: .outflow, emoji: "🍱")
            addCategory(name: "Housing", type: .outflow, emoji: "🏠")
            addCategory(name: "Lifestyle", type: .outflow, emoji: "🎨")
            addCategory(name: "Income", type: .inflow, emoji: "💰")
        }
        
        // MARK: - 3. Tags (The Keyword Lesson)
        // We create a "Magic Tag" to teach the search engine.
        if tags.isEmpty {
            // The Lesson: Don't make a tag for every coffee shop. Make one tag with keywords.
            addTag(name: "#Caffeine", keywords: ["starbucks", "dunkin", "espresso", "latte", "coffee"])
            addTag(name: "#Recurring", keywords: ["subscription", "netflix", "spotify", "monthly"])
        }
        
        // MARK: - 4. Templates (The Workflow Lesson)
        // Pre-built templates to teach the "Transfer" vs "Expense" logic.
        if templates.isEmpty {
            // We need IDs to link these, so we find the created objects first
            if let creditCard = accounts.first(where: { $0.name == "Daily Driver Card" }),
               let checking = accounts.first(where: { $0.name == "Main Checking" }),
               let sustenance = categories.first(where: { $0.name == "Sustenance" }),
               let caffeineTag = tags.first(where: { $0.name == "#Caffeine" }) {
                
                // Template 1: The Quick Spend (Coffee)
                // Teaches: Using Credit Card + Category + Tag
                addTemplate(
                    name: "Morning Coffee",
                    type: .outflow,
                    accountID: creditCard.id,
                    categoryID: sustenance.id,
                    tagIDs: [caffeineTag.id]
                )
                
                // Template 2: The Bill Pay
                // Teaches: Paying a credit card is a TRANSFER, not an expense.
                addTemplate(
                    name: "Pay Credit Bill",
                    type: .transfer,
                    accountID: checking.id, // From Checking
                    transferTargetAccountID: creditCard.id // To Credit Card
                )
            }
        }
    }
}
