import Foundation

enum CategoryType: String, Codable, CaseIterable, Identifiable, Sendable {
    case inflow
    case outflow
    var id: String { rawValue }
}

/// Categories the app creates for its own bookkeeping. Identified by this
/// role rather than by name, so renaming one (or creating your own
/// "Transfer" category) can't change how money is counted.
enum CategorySystemRole: String, Codable, Sendable {
    /// Both legs of a transfer between your own accounts.
    case transfer
    /// "The Plug" — a reconciliation adjustment.
    case reconciliationAdjustment
}

struct Category: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var type: CategoryType
    var emoji: String
    /// NEW: Archived categories are hidden from selection lists but preserved in history.
    var isArchived: Bool = false
    /// Set only on categories the app manages. nil for user categories.
    var systemRole: CategorySystemRole? = nil

    init(id: UUID = UUID(), name: String, type: CategoryType, emoji: String = "",
         isArchived: Bool = false, systemRole: CategorySystemRole? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.emoji = emoji
        self.isArchived = isArchived
        self.systemRole = systemRole
    }
    
    // MARK: - Codable Compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, type, emoji, isArchived, systemRole
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(CategoryType.self, forKey: .type)
        emoji = try container.decode(String.self, forKey: .emoji)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        // Absent in files written before roles existed; assigned on load
        // by TransactionStore.assignSystemRoles().
        systemRole = try container.decodeIfPresent(CategorySystemRole.self, forKey: .systemRole)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encodeIfPresent(systemRole, forKey: .systemRole)
    }
}
