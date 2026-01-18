import Foundation

struct TransactionTemplate: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var type: TransactionType
    var accountID: UUID?
    var categoryID: UUID?
    var tagIDs: [UUID]
    var isOutlier: Bool
    var transferTargetAccountID: UUID?
    
    // New: Reminder Schedule
    var reminderSchedule: ReminderSchedule?
}

struct ReminderSchedule: Codable, Hashable, Sendable {
    enum Frequency: String, CaseIterable, Codable, Identifiable, Sendable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        var id: String { rawValue }
    }
    
    var frequency: Frequency
    var time: DateComponents // Stores hour, minute
    var dayOfWeek: Int? // 1 = Sunday, 2 = Monday... (For Weekly)
    var dayOfMonth: Int? // 1-31 (For Monthly)
}
