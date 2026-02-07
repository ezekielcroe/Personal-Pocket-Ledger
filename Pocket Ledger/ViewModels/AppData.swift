import Foundation
import Combine
@preconcurrency import UserNotifications

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
@MainActor
class AppData: ObservableObject {
    
    // MARK: - Published Properties
    @Published var accounts: [Account] = []
    @Published var accountGroups: [AccountGroup] = []
    @Published var categories: [Category] = []
    @Published var tags: [Tag] = []
    @Published var transactions: [Transaction] = []
    @Published var templates: [TransactionTemplate] = []
    @Published var reminderTime: DateComponents = DateComponents(hour: 21, minute: 0)
    @Published var insightPresets: [InsightPreset] = []

    // MARK: - Book Management
    @Published var availableBooks: [BookMetadata] = []
    @Published var activeBook: BookMetadata?

    // MARK: - Services
    let storage = StorageService()

    init() {
            Task {
                // 1. Load any saved data from disk
                await loadIndex()
                
                // 2. Check if the app is empty, and if so, load the tutorial defaults
                await initializeDefaultsIfNeeded()
            }
        }
}
