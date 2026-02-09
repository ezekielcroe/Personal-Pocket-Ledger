import Foundation

enum CategoryType: String, Codable, CaseIterable, Identifiable, Sendable {
    case inflow
    case outflow
    var id: String { rawValue }
}

struct Category: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var type: CategoryType
    var emoji: String
    /// NEW: Archived categories are hidden from selection lists but preserved in history.
    var isArchived: Bool = false

    init(id: UUID = UUID(), name: String, type: CategoryType, emoji: String = "", isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.emoji = emoji
        self.isArchived = isArchived
    }
    
    // MARK: - Codable Compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, type, emoji, isArchived
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(CategoryType.self, forKey: .type)
        emoji = try container.decode(String.self, forKey: .emoji)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(isArchived, forKey: .isArchived)
    }
}
