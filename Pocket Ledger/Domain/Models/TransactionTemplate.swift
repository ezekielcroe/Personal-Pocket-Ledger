import Foundation

struct TransactionTemplate: Identifiable, Codable, Hashable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var type: TransactionType
    var accountID: UUID?
    var categoryID: UUID?
    var isOutlier: Bool
    var transferTargetAccountID: UUID?
    /// Pre-filled remark for the transaction form.
    var remark: String = ""
    /// Tag IDs read from templates saved before the tag system was removed.
    /// Decoded so their names can be migrated into `remark`, never re-encoded.
    var legacyTagIDs: [UUID] = []
    
    // New: Reminder Schedule
    var reminderSchedule: ReminderSchedule?
    
    // MARK: - Codable Compatibility
    // Custom decoding so templates saved before `remark` existed still load.
    enum CodingKeys: String, CodingKey {
        case id, name, type, accountID, categoryID
        case isOutlier, transferTargetAccountID, remark, reminderSchedule
        case legacyTagIDs = "tagIDs"
    }
    
    init(id: UUID = UUID(),
         name: String,
         type: TransactionType,
         accountID: UUID? = nil,
         categoryID: UUID? = nil,
         isOutlier: Bool = false,
         transferTargetAccountID: UUID? = nil,
         remark: String = "",
         reminderSchedule: ReminderSchedule? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.accountID = accountID
        self.categoryID = categoryID
        self.isOutlier = isOutlier
        self.transferTargetAccountID = transferTargetAccountID
        self.remark = remark
        self.reminderSchedule = reminderSchedule
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(TransactionType.self, forKey: .type)
        accountID = try container.decodeIfPresent(UUID.self, forKey: .accountID)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        isOutlier = try container.decodeIfPresent(Bool.self, forKey: .isOutlier) ?? false
        transferTargetAccountID = try container.decodeIfPresent(UUID.self, forKey: .transferTargetAccountID)
        remark = try container.decodeIfPresent(String.self, forKey: .remark) ?? ""
        reminderSchedule = try container.decodeIfPresent(ReminderSchedule.self, forKey: .reminderSchedule)
        legacyTagIDs = try container.decodeIfPresent([UUID].self, forKey: .legacyTagIDs) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(accountID, forKey: .accountID)
        try container.encodeIfPresent(categoryID, forKey: .categoryID)
        try container.encode(isOutlier, forKey: .isOutlier)
        try container.encodeIfPresent(transferTargetAccountID, forKey: .transferTargetAccountID)
        try container.encode(remark, forKey: .remark)
        try container.encodeIfPresent(reminderSchedule, forKey: .reminderSchedule)
        // legacyTagIDs intentionally not encoded
    }
}

struct ReminderSchedule: Codable, Hashable, Equatable, Sendable {
    enum Frequency: String, CaseIterable, Codable, Identifiable, Sendable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        var id: String { rawValue }
    }
    
    var frequency: Frequency
    var hour: Int
    var minute: Int
    var dayOfWeek: Int?
    var dayOfMonth: Int?
}
