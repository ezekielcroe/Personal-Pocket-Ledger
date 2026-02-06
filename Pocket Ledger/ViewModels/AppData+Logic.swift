//
//  AppData+Logic.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 5/2/26.
//

import Foundation
import Combine

extension AppData {
    // MARK: - Query Helpers

    func balance(for account: Account) -> Double {
        let inflow = transactions
            .filter { $0.accountID == account.id && $0.type == .inflow }
            .reduce(0) { $0 + $1.amount }
        let outflow = transactions
            .filter { $0.accountID == account.id && $0.type == .outflow }
            .reduce(0) { $0 + $1.amount }
        
        if account.isCredit {
            return account.initialAmount + outflow - inflow
        } else {
            return account.initialAmount + inflow - outflow
        }
    }

    func transactions(for account: Account) -> [Transaction] {
        transactions.filter { $0.accountID == account.id }
    }

    func transactions(for category: Category) -> [Transaction] {
        transactions.filter { $0.categoryID == category.id }
    }

    func transactions(for tag: Tag) -> [Transaction] {
        transactions.filter { $0.tagIDs.contains(tag.id) }
    }

    func stats(for account: Account) -> AccountStats {
        let accountTransactions = transactions(for: account)
        let inflowTransactions = accountTransactions.filter { $0.type == .inflow }
        let outflowTransactions = accountTransactions.filter { $0.type == .outflow }

        let totalInflow = inflowTransactions.reduce(0) { $0 + $1.amount }
        let totalOutflow = outflowTransactions.reduce(0) { $0 + $1.amount }

        let dates = accountTransactions.map { $0.date }
        let start = dates.min() ?? account.created
        let end = dates.max() ?? account.created
        
        let dayComponents = Calendar.current.dateComponents([.day], from: start, to: end)
        let totalDays = max((dayComponents.day ?? 0) + 1, 1)
        
        let weeks = max(Double(totalDays) / 7.0, 1.0)
        let months = max(Double(totalDays) / 30.0, 1.0)
        let years = max(Double(totalDays) / 365.0, 1.0)

        return AccountStats(
            totalInflow: totalInflow,
            totalOutflow: totalOutflow,
            dailyInflow: totalInflow / Double(totalDays),
            weeklyInflow: totalInflow / weeks,
            monthlyInflow: totalInflow / months,
            yearlyInflow: totalInflow / years,
            dailyOutflow: totalOutflow / Double(totalDays),
            weeklyOutflow: totalOutflow / weeks,
            monthlyOutflow: totalOutflow / months,
            yearlyOutflow: totalOutflow / years
        )
    }
    
    // MARK: - Account Group Operations (Fixed Double-Counting)
    /// Calculates balance for a group by summing unique member accounts.
    /// This fixes double-counting by flattening the hierarchy into a unique set of accounts.
    func groupBalance(_ group: AccountGroup) -> Double {
        // 1. Get all unique account IDs in this group hierarchy
        // (Requires the updated AccountGroup.swift which returns a Set)
        let uniqueAccountIDs = group.allAccountIDs(in: accountGroups, accounts: accounts)
        
        var total: Double = 0
        
        // 2. Sum them up (applying Debit vs Credit logic)
        for accountID in uniqueAccountIDs {
            if let account = accounts.first(where: { $0.id == accountID }) {
                let accountBalance = balance(for: account)
                
                // Credit accounts (debts) subtract from total wealth
                if account.isCredit {
                    total -= accountBalance
                } else {
                    total += accountBalance
                }
            }
        }
        
        return total
    }
    
    /// Returns all members (accounts + groups) for a group
    func members(for group: AccountGroup) -> [MemberType] {
        var result: [MemberType] = []
        
        for memberID in group.memberIDs {
            if let account = accounts.first(where: { $0.id == memberID }) {
                result.append(.account(account))
            } else if let childGroup = accountGroups.first(where: { $0.id == memberID }) {
                result.append(.group(childGroup))
            }
        }
        
        return result
    }
    
    /// Safely adds a member to a group (with cycle detection)
    func addMember(_ memberID: UUID, to groupID: UUID) throws {
        guard let index = accountGroups.firstIndex(where: { $0.id == groupID }) else {
            throw GroupError.groupNotFound
        }
        
        var group = accountGroups[index]
        
        // Check for cycles if adding a group
        if accountGroups.contains(where: { $0.id == memberID }) {
            if group.wouldCreateCycle(byAdding: memberID, in: accountGroups) {
                throw GroupError.wouldCreateCycle
            }
        }
        
        // Check for duplicates
        if group.memberIDs.contains(memberID) {
            throw GroupError.memberAlreadyExists
        }
        
        group.memberIDs.append(memberID)
        accountGroups[index] = group
        save()
    }
    
    /// Removes a member from a group
    func removeMember(_ memberID: UUID, from groupID: UUID) {
        guard let index = accountGroups.firstIndex(where: { $0.id == groupID }) else {
            return
        }
        
        var group = accountGroups[index]
        group.memberIDs.removeAll { $0 == memberID }
        accountGroups[index] = group
        save()
    }
    
    /// Returns the depth of nesting for a group
    func depth(of group: AccountGroup) -> Int {
        group.depth(in: accountGroups)
    }
    
    /// Returns all account IDs in a group (flattened, recursive)
    func allAccountIDs(in group: AccountGroup) -> [UUID] {
        // Convert the Set (from updated AccountGroup.swift) back to Array
        Array(group.allAccountIDs(in: accountGroups, accounts: accounts))
    }
    
    /// Validates group structure integrity
    func validateGroupStructure() -> [GroupValidationError] {
        var errors: [GroupValidationError] = []
        
        for group in accountGroups {
            // Check for cycles
            for memberID in group.memberIDs {
                if accountGroups.contains(where: { $0.id == memberID }) {
                    if group.wouldCreateCycle(byAdding: memberID, in: accountGroups) {
                        errors.append(.cycle(groupName: group.name))
                    }
                }
            }
            
            // Check for orphaned references
            for memberID in group.memberIDs {
                let isAccount = accounts.contains(where: { $0.id == memberID })
                let isGroup = accountGroups.contains(where: { $0.id == memberID })
                
                if !isAccount && !isGroup {
                    errors.append(.orphanedMember(groupName: group.name, memberID: memberID))
                }
            }
        }
        
        return errors
    }
}

// MARK: - Error Types

enum GroupError: LocalizedError {
    case groupNotFound
    case wouldCreateCycle
    case memberAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .groupNotFound:
            return "Group not found"
        case .wouldCreateCycle:
            return "Adding this group would create a circular reference"
        case .memberAlreadyExists:
            return "This member is already in the group"
        }
    }
}

enum GroupValidationError: Identifiable {
    case cycle(groupName: String)
    case orphanedMember(groupName: String, memberID: UUID)
    
    var id: String {
        switch self {
        case .cycle(let name):
            return "cycle-\(name)"
        case .orphanedMember(let name, let id):
            return "orphan-\(name)-\(id)"
        }
    }
    
    var description: String {
        switch self {
        case .cycle(let name):
            return "Circular reference detected in group: \(name)"
        case .orphanedMember(let name, let id):
            return "Orphaned member in group '\(name)': \(id)"
        }
    }
}
