import Foundation

/// Represents a secondary label that can be attached to transactions.
///
/// Tags provide flexible sub-categorisation across categories. A tag might
/// represent a context ("vacation"), a spending mood ("discretionary") or
/// any other descriptor that helps organise financial records.

struct Tag: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    /// NEW: Keywords act as aliases for search purposes only.
    var keywords: [String] = []

    init(id: UUID = UUID(), name: String, keywords: [String] = []) {
        self.id = id
        self.name = name
        self.keywords = keywords
    }
    
    // MARK: - Codable Compatibility
    // This ensures old backup files without "keywords" can still be loaded.
    enum CodingKeys: String, CodingKey {
        case id, name, keywords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // If 'keywords' is missing in the JSON (legacy data), default to empty array
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(keywords, forKey: .keywords)
    }
}
