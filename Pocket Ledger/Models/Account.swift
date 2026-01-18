import Foundation

/// Represents a financial container such as a bank account, credit card, savings goal, or budget envelope.
///
/// Each `Account` has a unique identifier, a name, an initial amount and a creation date.
/// The `initialAmount` reflects the starting balance when the account is created.
/// Subsequent transactions will modify the running balance.
///
/// Accounts can be categorized into four types based on `isCredit` and `targetAmount`:
/// - **Debit** (isCredit: false, targetAmount: nil): Cash, checking accounts
/// - **Credit** (isCredit: true, targetAmount: nil): Credit cards, loans
/// - **Goal** (isCredit: false, targetAmount: set): Savings goals with targets
/// - **Budget** (isCredit: true, targetAmount: set): Envelope budgets with spending limits

struct Account: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier for the account.
    let id: UUID
    /// Human-readable name for the account.
    var name: String
    /// Starting balance when the account is first recorded.
    var initialAmount: Double
    /// Date when the account record was created.
    var created: Date
    
    /// Indicates whether this account functions as a credit account.
    /// - For debit accounts: balance increases with inflows, decreases with outflows
    /// - For credit accounts: balance increases with outflows (debt/spending), decreases with inflows (payments)
    var isCredit: Bool = false
    
    /// Optional target amount for goal tracking or budget limits.
    /// - For debit accounts: represents a savings goal to reach
    /// - For credit accounts: represents a spending budget limit
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
