import Foundation

/// Represents a secondary label that can be attached to transactions.
///
/// Tags provide flexible sub-categorisation across categories. A tag might
/// represent a context ("vacation"), a spending mood ("discretionary") or
/// any other descriptor that helps organise financial records.
struct Tag: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier for the tag.
    let id: UUID
    /// Short name or descriptor for the tag.
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
