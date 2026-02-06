import Foundation

/// Represents a financial container such as a bank account, credit card, savings goal, or debt.
///
/// Accounts can be categorized into four types based on `isCredit` and `targetAmount`:
/// - **Debit** (isCredit: false, targetAmount: nil): Cash, checking accounts
/// - **Goal** (isCredit: false, targetAmount: set): Savings goals with target dates
/// - **Budget** (isCredit: true, targetAmount: set): Spending envelopes with monthly limits
/// - **Debt** (isCredit: true, targetAmount: nil or 0): Loans, installments with payoff goals
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
    
    /// Optional target amount for goal tracking, budget limits, or debt payoff.
    /// - For debit accounts: represents a savings goal to reach
    /// - For budget accounts: represents a spending limit
    /// - For debt accounts: typically nil or 0 (payoff goal)
    var targetAmount: Double? = nil
    
    /// Optional target date for reaching a goal or paying off debt.
    /// Used to calculate required periodic contributions/payments.
    var targetDate: Date? = nil
    
    /// Frequency of contributions (Goals) or payments (Debts).
    /// Used with targetDate to calculate installment amounts.
    var paymentFrequency: PaymentFrequency? = nil
    
    /// Date when the account was archived. If nil, account is active.
    var archivedDate: Date? = nil
    
    /// Computed property to check if account is archived
    var isArchived: Bool {
        archivedDate != nil
    }
    
    init(id: UUID = UUID(),
         name: String,
         initialAmount: Double = 0.0,
         created: Date = Date(),
         isCredit: Bool = false,
         targetAmount: Double? = nil,
         targetDate: Date? = nil,
         paymentFrequency: PaymentFrequency? = nil,
         archivedDate: Date? = nil) {
        self.id = id
        self.name = name
        self.initialAmount = initialAmount
        self.created = created
        self.isCredit = isCredit
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.paymentFrequency = paymentFrequency
        self.archivedDate = archivedDate
    }
    
    /// Computed property for account type classification
    var accountType: AccountType {
        switch (isCredit, targetAmount) {
        case (false, nil):
            return .debit
        case (false, .some(let target)) where target > 0:
            return .goal
        case (true, .some(let target)) where target > 0:
            return .budget
        case (true, nil), (true, .some(0)):
            return .debt
        default:
            return .debt
        }
    }
}

// MARK: - Supporting Enums

enum AccountType: String, Codable, Sendable {
    case debit = "Debit"
    case goal = "Goal"
    case budget = "Budget"
    case debt = "Debt"
    
    /// SF Symbol icon for each account type
    var icon: String {
        switch self {
        case .debit:  return "banknote"
        case .goal:   return "target"
        case .budget: return "envelope.fill"
        case .debt:   return "creditcard.fill"
        }
    }
    
    /// Section header name (for grouping)
    var sectionName: String {
        self.rawValue
    }
}

enum PaymentFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
    
    var id: String { rawValue }
    
    /// Returns the number of periods per year
    var periodsPerYear: Double {
        switch self {
        case .weekly:    return 52
        case .biweekly:  return 26
        case .monthly:   return 12
        case .quarterly: return 4
        case .yearly:    return 1
        }
    }
    
    /// Calculates total number of periods between two dates
    func periodsBetween(from start: Date, to end: Date) -> Int {
        let calendar = Calendar.current
        let components: Calendar.Component
        let multiplier: Int
        
        switch self {
        case .weekly:
            components = .weekOfYear
            multiplier = 1
        case .biweekly:
            components = .weekOfYear
            multiplier = 2
        case .monthly:
            components = .month
            multiplier = 1
        case .quarterly:
            components = .month
            multiplier = 3
        case .yearly:
            components = .year
            multiplier = 1
        }
        
        let difference = calendar.dateComponents([components], from: start, to: end)
        let rawPeriods = difference.value(for: components) ?? 0
        
        if multiplier == 1 {
            return rawPeriods
        } else {
            return rawPeriods / multiplier
        }
    }
}
