//
//  AccountStatusBadge.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 25/1/26.
//


import SwiftUI

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
    func statusBadge(balance: Decimal) -> AccountStatusBadge? {
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
