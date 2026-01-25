import SwiftUI

// MARK: - AccountType Visual Extensions

extension AccountType {
    /// SF Symbol icon for each account type
    var icon: String {
        switch self {
        case .debit:  return "banknote"
        case .goal:   return "target"
        case .budget: return "envelope.fill"
        case .debt:   return "creditcard.fill"
        }
    }
    
    /// Primary color for each account type
    var color: Color {
        switch self {
        case .debit:  return .green
        case .goal:   return .blue
        case .budget: return .purple
        case .debt:   return .orange
        }
    }
    
    /// Section header name (for grouping)
    var sectionName: String {
        switch self {
        case .debit:  return "Debit"
        case .goal:   return "Goals"
        case .budget: return "Budgets"
        case .debt:   return "Debts"
        }
    }
}

// MARK: - Account Status Badge

enum AccountStatusBadge {
    case goalMet
    case budgetExceeded
    case archived
    
    var icon: String {
        switch self {
        case .goalMet:        return "checkmark.circle.fill"
        case .budgetExceeded: return "exclamationmark.triangle.fill"
        case .archived:       return "archivebox.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .goalMet:        return .green
        case .budgetExceeded: return .red
        case .archived:       return .secondary
        }
    }
}

// MARK: - Account Status Helper

extension Account {
    /// Determines if account should show a status badge
    func statusBadge(balance: Double) -> AccountStatusBadge? {
        if isArchived {
            return .archived
        }
        
        switch accountType {
        case .goal:
            if let target = targetAmount, balance >= target {
                return .goalMet
            }
        case .budget:
            if let target = targetAmount, balance > target {
                return .budgetExceeded
            }
        default:
            break
        }
        
        return nil
    }
}

// MARK: - Compact Account Badge View

struct AccountStatusBadgeView: View {
    let badge: AccountStatusBadge
    
    var body: some View {
        Image(systemName: badge.icon)
            .font(.caption2)
            .foregroundColor(badge.color)
    }
}

// MARK: - Account Type Icon View

struct AccountTypeIcon: View {
    let type: AccountType
    let size: CGFloat
    
    init(type: AccountType, size: CGFloat = 20) {
        self.type = type
        self.size = size
    }
    
    var body: some View {
        Image(systemName: type.icon)
            .font(.system(size: size * 0.6))
            .foregroundColor(type.color)
            .frame(width: size, height: size)
            .background(type.color.opacity(0.15))
            .clipShape(Circle())
    }
}