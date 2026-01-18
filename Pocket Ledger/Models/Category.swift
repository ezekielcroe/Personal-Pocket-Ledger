import Foundation

/// Distinguishes whether a transaction is money coming in or going out.
///
/// Categories are separated by type so that inflows and outflows do not
/// overlap. This allows the user to define different sets of categories
/// for income and expenses.
enum CategoryType: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Money added to an account (income).
    case inflow
    /// Money removed from an account (expense).
    case outflow

    var id: String { rawValue }
}

/// A primary classification for transactions.
///
/// Categories group transactions into broad buckets (e.g. rent, groceries,
/// salary). Each category belongs to either the inflow or outflow type and
/// may have an emoji to aid recognition in the user interface.
struct Category: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier for the category.
    let id: UUID
    /// Display name of the category.
    var name: String
    /// Indicates whether the category applies to an inflow or outflow.
    var type: CategoryType
    /// Optional emoji for quick visual identification.
    var emoji: String

    init(id: UUID = UUID(), name: String, type: CategoryType, emoji: String = "") {
        self.id = id
        self.name = name
        self.type = type
        self.emoji = emoji
    }
}
