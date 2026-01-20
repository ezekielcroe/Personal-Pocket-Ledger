import Foundation
import Combine
import UserNotifications

// MARK: - Data Models

struct AccountStats {
    var totalInflow: Double
    var totalOutflow: Double
    var dailyInflow: Double
    var weeklyInflow: Double
    var monthlyInflow: Double
    var yearlyInflow: Double
    var dailyOutflow: Double
    var weeklyOutflow: Double
    var monthlyOutflow: Double
    var yearlyOutflow: Double
}

// MARK: - AppData Store

/// Central store for all user data in the budgeting app.
@MainActor
class AppData: ObservableObject {
    
    // MARK: - Published Properties (Current Book Data)
    @Published var accounts: [Account] = []
    @Published var accountGroups: [AccountGroup] = [] // NEW: Account Groups
    @Published var categories: [Category] = []
    @Published var tags: [Tag] = []
    @Published var transactions: [Transaction] = []
    @Published var templates: [TransactionTemplate] = []
    @Published var reminderTime: DateComponents = DateComponents(hour: 21, minute: 0)
    @Published var insightPresets: [InsightPreset] = []

    // MARK: - Book Management
    @Published var availableBooks: [BookMetadata] = []
    @Published var activeBook: BookMetadata?

    // MARK: - File Paths
    
    private var indexURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("book_index.json")
    }
    
    private func dataURL(for book: BookMetadata) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(book.fileName)
    }

    init() {
        Task {
            await loadIndex()
        }
    }
    
    // MARK: - Index Operations
    
    private func saveIndex() {
        let index = BookIndex(books: availableBooks, lastActiveBookID: activeBook?.id)
        
        Task.detached(priority: .background) {
            let url = await self.indexURL
            do {
                let data = try JSONEncoder().encode(index)
                try data.write(to: url, options: [.atomic])
            } catch {
                print("Failed to save book index: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadIndex() async {
        let url = indexURL
        
        let loadedIndex = await Task.detached(priority: .userInitiated) { () -> BookIndex? in
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(BookIndex.self, from: data)
            } catch {
                return nil
            }
        }.value
        
        if let index = loadedIndex {
            self.availableBooks = index.books
            
            if let lastID = index.lastActiveBookID,
               let match = index.books.first(where: { $0.id == lastID }) {
                await loadBook(match)
            } else if let firstBook = index.books.first {
                await loadBook(firstBook)
            } else {
                await createDefaultBook()
            }
        } else {
            await createDefaultBook()
        }
    }
    
    private func createDefaultBook() async {
        let defaultBook = BookMetadata(name: "My Ledger")
        self.availableBooks = [defaultBook]
        saveIndex()
        await loadBook(defaultBook)
    }

    // MARK: - Book Loading & Saving

    func loadBook(_ book: BookMetadata) async {
        self.activeBook = book
        
        if let index = availableBooks.firstIndex(where: { $0.id == book.id }) {
            availableBooks[index].lastOpened = Date()
            saveIndex()
        }
        
        let url = dataURL(for: book)
        
        let loadedData = await Task.detached(priority: .userInitiated) { () -> SavedData? in
            do {
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(SavedData.self, from: data)
            } catch {
                print("Error decoding book data: \(error.localizedDescription)")
                return nil
            }
        }.value
        
        if let decoded = loadedData {
            self.accounts = decoded.accounts
            self.accountGroups = decoded.accountGroups ?? []
            self.categories = decoded.categories
            self.tags = decoded.tags
            self.transactions = decoded.transactions
            self.templates = decoded.templates ?? []
            self.insightPresets = decoded.insightPresets ?? []
            self.reminderTime = decoded.reminderTime ?? DateComponents(hour: 21, minute: 0)
            updateReminders()
        } else {
            resetToEmpty()
            await initializeDefaultsIfNeeded()
        }
    }

    func save() {
        guard let currentBook = activeBook else { return }
        let url = dataURL(for: currentBook)
        
        let dataToSave = SavedData(
            accounts: accounts,
            accountGroups: accountGroups,
            categories: categories,
            tags: tags,
            transactions: transactions,
            templates: templates,
            reminderTime: reminderTime,
            insightPresets: insightPresets
        )
        
        Task.detached(priority: .background) {
            do {
                let data = try JSONEncoder().encode(dataToSave)
                try data.write(to: url, options: [.atomic, .completeFileProtection])
            } catch {
                print("Error saving data: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - CREATE Operations

    func addAccount(name: String,
                    initialAmount: Double,
                    isCredit: Bool = false,
                    targetAmount: Double? = nil,
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
    
    func addAccountGroup(name: String, accountIDs: [UUID]) {
        let group = AccountGroup(name: name, accountIDs: accountIDs)
        accountGroups.append(group)
        save()
    }

    func addCategory(name: String, type: CategoryType, emoji: String) {
        let category = Category(name: name, type: type, emoji: emoji)
        categories.append(category)
        save()
    }

    func addTag(name: String) {
        let tag = Tag(name: name)
        tags.append(tag)
        save()
    }

    func addTransaction(type: TransactionType,
                        accountID: UUID,
                        categoryID: UUID,
                        tagIDs: [UUID],
                        amount: Double,
                        date: Date,
                        isOutlier: Bool = false) {
        let transaction = Transaction(type: type,
                                      accountID: accountID,
                                      categoryID: categoryID,
                                      tagIDs: tagIDs,
                                      amount: amount,
                                      date: date,
                                      isOutlier: isOutlier)
        transactions.append(transaction)
        save()
    }

    // MARK: - UPDATE & DELETE Operations

    func updateAccount(id: UUID,
                       name: String,
                       initialAmount: Double,
                       targetAmount: Double? = nil,
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
            accountGroups[i].accountIDs.removeAll { $0 == account.id }
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

    func updateCategory(id: UUID, name: String, type: CategoryType, emoji: String) {
        if let index = categories.firstIndex(where: { $0.id == id }) {
            categories[index].name = name
            categories[index].type = type
            categories[index].emoji = emoji
            save()
        }
    }

    func updateTag(id: UUID, name: String) {
        if let index = tags.firstIndex(where: { $0.id == id }) {
            tags[index].name = name
            save()
        }
    }
    
    func updateTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            save()
        }
    }

    func removeTagFromTransactions(tagID: UUID) {
        for i in 0..<transactions.count {
            if transactions[i].tagIDs.contains(tagID) {
                transactions[i].tagIDs.removeAll { $0 == tagID }
            }
        }
        save()
    }

    // MARK: - Template Operations

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
    
    // MARK: - Preset Operations
    
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

    // MARK: - Reminder Logic

    func updateReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        for template in templates {
            if let schedule = template.reminderSchedule {
                scheduleNotification(for: template, schedule: schedule)
            }
        }
    }

    private func scheduleNotification(for template: TransactionTemplate, schedule: ReminderSchedule) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Record Transaction"
        content.body = "Time to record: \(template.name)"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = schedule.time.hour
        dateComponents.minute = schedule.time.minute
        
        switch schedule.frequency {
        case .daily:
            break
        case .weekly:
            dateComponents.weekday = schedule.dayOfWeek
        case .monthly:
            dateComponents.day = schedule.dayOfMonth
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: template.id.uuidString, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Data Management

    func resetAllData() {
        resetToEmpty()
        save()
        Task { await initializeDefaultsIfNeeded() }
    }
    
    private func resetToEmpty() {
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
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "Permissions", code: 403, userInfo: [NSLocalizedDescriptionKey: "Permission denied to access file."])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(SavedData.self, from: data)
        
        self.accounts = decoded.accounts
        self.accountGroups = decoded.accountGroups ?? []
        self.categories = decoded.categories
        self.tags = decoded.tags
        self.transactions = decoded.transactions
        self.templates = decoded.templates ?? []
        self.insightPresets = decoded.insightPresets ?? []
        self.reminderTime = decoded.reminderTime ?? DateComponents(hour: 21, minute: 0)
        
        save()
        updateReminders()
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
    
    // MARK: - Query Helpers

    func balance(for account: Account) -> Double {
        let inflow = transactions
            .filter { $0.accountID == account.id && $0.type == .inflow }
            .reduce(0) { $0 + $1.amount }
        let outflow = transactions
            .filter { $0.accountID == account.id && $0.type == .outflow }
            .reduce(0) { $0 + $1.amount }
        
        if account.isCredit {
            // Credit: Outflows increase balance (debt/spending grows)
            // Inflows decrease balance (payments reduce debt/spending)
            return account.initialAmount + outflow - inflow
        } else {
            // Debit: Inflows increase balance (money in)
            // Outflows decrease balance (money out)
            return account.initialAmount + inflow - outflow
        }
    }
    
    func balance(for group: AccountGroup) -> Double {
        group.accountIDs.reduce(0) { partialResult, accountID in
            if let account = accounts.first(where: { $0.id == accountID }) {
                let accountBalance = balance(for: account)
                
                // Credit accounts represent debt/spending, so subtract them
                if account.isCredit {
                    return partialResult - accountBalance
                } else {
                    return partialResult + accountBalance
                }
            }
            return partialResult
        }
    }

    func transactions(for account: Account) -> [Transaction] {
        transactions.filter { $0.accountID == account.id }
    }

    func transactions(for category: Category) -> [Transaction] {
        transactions.filter { $0.categoryID == category.id }
    }

    func transactions(for tag: Tag) -> [Transaction] {
        transactions.filter { $0.tagIDs.contains(tag.id) }
    }

    func stats(for account: Account) -> AccountStats {
        let accountTransactions = transactions(for: account)
        let inflowTransactions = accountTransactions.filter { $0.type == .inflow }
        let outflowTransactions = accountTransactions.filter { $0.type == .outflow }

        let totalInflow = inflowTransactions.reduce(0) { $0 + $1.amount }
        let totalOutflow = outflowTransactions.reduce(0) { $0 + $1.amount }

        let dates = accountTransactions.map { $0.date }
        let start = dates.min() ?? account.created
        let end = dates.max() ?? account.created
        
        let dayComponents = Calendar.current.dateComponents([.day], from: start, to: end)
        let totalDays = max((dayComponents.day ?? 0) + 1, 1)
        
        let weeks = max(Double(totalDays) / 7.0, 1.0)
        let months = max(Double(totalDays) / 30.0, 1.0)
        let years = max(Double(totalDays) / 365.0, 1.0)

        return AccountStats(
            totalInflow: totalInflow,
            totalOutflow: totalOutflow,
            dailyInflow: totalInflow / Double(totalDays),
            weeklyInflow: totalInflow / weeks,
            monthlyInflow: totalInflow / months,
            yearlyInflow: totalInflow / years,
            dailyOutflow: totalOutflow / Double(totalDays),
            weeklyOutflow: totalOutflow / weeks,
            monthlyOutflow: totalOutflow / months,
            yearlyOutflow: totalOutflow / years
        )
    }
}
