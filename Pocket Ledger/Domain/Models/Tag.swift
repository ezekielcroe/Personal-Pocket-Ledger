import Foundation

/// Represents a secondary label that can be attached to transactions.
/// 
struct Tag: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    /// Keywords act as aliases for search purposes only.
    var keywords: [String] = []
    /// NEW: Archived tags are hidden from selection lists but preserved in history.
    var isArchived: Bool = false

    init(id: UUID = UUID(), name: String, keywords: [String] = [], isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.keywords = keywords
        self.isArchived = isArchived
    }
    
    // MARK: - Codable Compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, keywords, isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        // Default to false if missing (for legacy data)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(keywords, forKey: .keywords)
        try container.encode(isArchived, forKey: .isArchived)
    }
}
