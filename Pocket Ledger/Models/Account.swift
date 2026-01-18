import Foundation

/// Represents a financial container such as a bank account or a wallet.
///
/// Each `Account` has a unique identifier, a name, an initial amount and a
/// creation date. The `initialAmount` reflects the balance at the time
/// the account is created in the app; subsequent transactions will modify
/// the running balance.
struct Account: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier for the account.
    let id: UUID
    /// Human-readable name for the account.
    var name: String
    /// Starting balance when the account is first recorded.
    var initialAmount: Double
    /// Date when the account record was created.
    var created: Date

    /// Indicates whether this account functions as a credit account.  A
    /// credit account is one where the ``initialAmount`` represents the
    /// monthly credit limit or budget rather than an actual balance.  When
    /// computing the current balance for a credit account the initial
    /// amount is treated as available credit, so spending reduces the
    /// balance and incoming payments restore it.  Defaults to `false` for
    /// typical cash or bank accounts.
    var isCredit: Bool = false
    
    var targetAmount: Double? = nil

    init(id: UUID = UUID(),
         name: String,
         initialAmount: Double = 0.0,
         created: Date = Date(),
         isCredit: Bool = false,
         targetAmount: Double? = nil) {
        self.id = id
        self.name = name
        self.initialAmount = initialAmount
        self.created = created
        self.isCredit = isCredit
        self.targetAmount = targetAmount

    }
}
