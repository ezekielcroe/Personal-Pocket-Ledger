//
//  FinancialCalculator.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 10/2/26.
//

import Foundation

struct AccountStats {
    var totalInflow: Decimal
    var totalOutflow: Decimal
    var dailyInflow: Decimal
    var weeklyInflow: Decimal
    var monthlyInflow: Decimal
    var yearlyInflow: Decimal
    var dailyOutflow: Decimal
    var weeklyOutflow: Decimal
    var monthlyOutflow: Decimal
    var yearlyOutflow: Decimal
}

/// Pure logic struct. No state. Just inputs and outputs.
struct FinancialCalculator {

    // MARK: - Account Balance
    
    /// Calculates the current balance for a single account based on the provided transaction history.
    static func balance(for account: Account, in transactions: [Transaction]) -> Decimal {
        // Logic extracted from
        let inflow = transactions
            .filter { $0.accountID == account.id && $0.type == .inflow }
            .reduce(Decimal.zero) { $0 + $1.amount }

        let outflow = transactions
            .filter { $0.accountID == account.id && $0.type == .outflow }
            .reduce(Decimal.zero) { $0 + $1.amount }

        if account.isCredit {
            return account.initialAmount + outflow - inflow
        } else {
            return account.initialAmount + inflow - outflow
        }
    }

    // MARK: - Account Statistics
    
    /// Generates statistics (daily/weekly/monthly averages) for an account.
    static func stats(for account: Account, in transactions: [Transaction]) -> AccountStats {
        // Filter transactions for this specific account
        // Previously relied on internal helper
        let accountTransactions = transactions.filter { $0.accountID == account.id }
        
        let inflowTransactions = accountTransactions.filter { $0.type == .inflow }
        let outflowTransactions = accountTransactions.filter { $0.type == .outflow }

        let totalInflow = inflowTransactions.reduce(Decimal.zero) { $0 + $1.amount }
        let totalOutflow = outflowTransactions.reduce(Decimal.zero) { $0 + $1.amount }

        let dates = accountTransactions.map { $0.date }
        let start = dates.min() ?? account.created
        let end = dates.max() ?? account.created
        
        let dayComponents = Calendar.current.dateComponents([.day], from: start, to: end)
        let totalDays = max((dayComponents.day ?? 0) + 1, 1)
        
        let totalDaysDecimal = Decimal(totalDays)
        let weeks = max(totalDaysDecimal / 7, 1)
        let months = max(totalDaysDecimal / 30, 1)
        let years = max(totalDaysDecimal / 365, 1)

        // Logic extracted from
        return AccountStats(
            totalInflow: totalInflow,
            totalOutflow: totalOutflow,
            dailyInflow: totalInflow / totalDaysDecimal,
            weeklyInflow: totalInflow / weeks,
            monthlyInflow: totalInflow / months,
            yearlyInflow: totalInflow / years,
            dailyOutflow: totalOutflow / totalDaysDecimal,
            weeklyOutflow: totalOutflow / weeks,
            monthlyOutflow: totalOutflow / months,
            yearlyOutflow: totalOutflow / years
        )
    }
    
    // MARK: - Group Balance
    
    /// Calculates balance for a group by summing unique member accounts.
    /// Requires access to all groups (for recursion) and all accounts (for lookups).
    static func groupBalance(_ group: AccountGroup,
                             in accountGroups: [AccountGroup],
                             accounts: [Account],
                             transactions: [Transaction]) -> Decimal {
        
        // 1. Get all unique account IDs in this group hierarchy
        // Logic extracted from
        let uniqueAccountIDs = group.allAccountIDs(in: accountGroups, accounts: accounts)
        
        var total: Decimal = 0
        
        // 2. Sum them up (applying Debit vs Credit logic)
        for accountID in uniqueAccountIDs {
            if let account = accounts.first(where: { $0.id == accountID }) {
                // RECURSION: We call our own static `balance` function here
                let accountBalance = balance(for: account, in: transactions)
                
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
}
