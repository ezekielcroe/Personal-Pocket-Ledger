import SwiftUI

struct AccountGroupDetailView: View {
    @EnvironmentObject var data: AppData
    let group: AccountGroup
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    var body: some View {
        List {
            // SECTION 1: Total Balance
            Section(header: Text("Total")) {
                HStack {
                    Text("Group Balance")
                        .font(.headline)
                    Spacer()
                    Text(data.balance(for: group).formattedCurrency(symbol: currencySymbol))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(totalBalanceColor)
                }
            }
            
            // SECTION 2: Breakdown by Account
            Section(header: Text("Accounts in Group"), footer: Text(balanceCalculationExplanation)) {
                ForEach(group.accountIDs, id: \.self) { id in
                    if let account = data.accounts.first(where: { $0.id == id }) {
                        NavigationLink(destination: AccountDetailView(account: account)) {
                            accountBreakdownRow(for: account)
                        }
                    }
                }
            }
            
            // SECTION 3: Statistics (This Period)
            Section(header: Text("Statistics")) {
                let totals = calculateGroupMonthlyTotals()
                StatRow(title: "Inflow (This Month)", value: totals.inflow, symbol: currencySymbol, color: .green)
                StatRow(title: "Outflow (This Month)", value: totals.outflow, symbol: currencySymbol, color: .red)
            }
            
            // SECTION 4: Recent Activity
            Section(header: Text("Recent Activity")) {
                let recent = data.transactions
                    .filter { group.accountIDs.contains($0.accountID) }
                    .sorted { $0.date > $1.date }
                    .prefix(25)
                
                if recent.isEmpty {
                    Text("No transactions in this group.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(recent) { tx in
                        NavigationLink(destination: TransactionDetailView(transaction: tx)) {
                            TransactionRow(transaction: tx)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
    }
    
    // MARK: - Account Breakdown Row
    
    @ViewBuilder
    private func accountBreakdownRow(for account: Account) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)
                
                // Show account type badge
                HStack(spacing: 4) {
                    Image(systemName: accountTypeIcon(for: account))
                        .font(.caption2)
                    Text(accountTypeLabel(for: account))
                        .font(.caption)
                }
                .foregroundColor(accountTypeLabelColor(for: account))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Main balance
                Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(accountBalanceColor(for: account))
                
                // Show contribution to group total
                Text(contributionText(for: account))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Functions
    
    private func accountTypeIcon(for account: Account) -> String {
        switch (account.isCredit, account.targetAmount) {
        case (false, nil):   return "dollarsign.circle"      // Debit
        case (true, nil):    return "creditcard"             // Credit
        case (false, .some): return "target"                 // Goal
        case (true, .some):  return "chart.bar.doc.horizontal" // Budget
        }
    }
    
    private func accountTypeLabel(for account: Account) -> String {
        switch (account.isCredit, account.targetAmount) {
        case (false, nil):   return "Debit"
        case (true, nil):    return "Credit"
        case (false, .some): return "Goal"
        case (true, .some):  return "Budget"
        }
    }
    
    private func accountTypeLabelColor(for account: Account) -> Color {
        switch (account.isCredit, account.targetAmount) {
        case (false, .some): return .blue    // Goal
        case (true, .some):  return .purple  // Budget
        default:             return .secondary
        }
    }
    
    private func accountBalanceColor(for account: Account) -> Color {
        let balance = data.balance(for: account)
        
        if account.isCredit {
            // Credit: Warn if high
            if balance > account.initialAmount * 0.9 {
                return .red
            } else if balance > account.initialAmount * 0.7 {
                return .orange
            }
        } else {
            // Debit: Warn if negative
            if balance < 0 {
                return .red
            }
        }
        return .primary
    }
    
    /// Shows how this account contributes to the group total
    private func contributionText(for account: Account) -> String {
        let balance = data.balance(for: account)
        
        if account.isCredit {
            // Credit accounts are subtracted from total
            return "(\(balance.formattedCurrency(symbol: currencySymbol)))"
        } else {
            // Debit accounts are added to total
            return "+\(balance.formattedCurrency(symbol: currencySymbol))"
        }
    }
    
    /// Color for the total balance
    private var totalBalanceColor: Color {
        let total = data.balance(for: group)
        return total < 0 ? .red : .primary
    }
    
    /// Explains how the balance is calculated
    private var balanceCalculationExplanation: String {
        let hasDebit = group.accountIDs.contains { id in
            data.accounts.first(where: { $0.id == id })?.isCredit == false
        }
        let hasCredit = group.accountIDs.contains { id in
            data.accounts.first(where: { $0.id == id })?.isCredit == true
        }
        
        if hasDebit && hasCredit {
            return "Group total = Debit accounts (+) minus Credit accounts (−). Credit balances shown in parentheses are subtracted from the total."
        } else if hasCredit {
            return "Group total = Sum of all credit balances. Negative total means net debt."
        } else {
            return "Group total = Sum of all debit balances."
        }
    }
    
    // MARK: - Statistics Calculation
    
    private func calculateGroupMonthlyTotals() -> (inflow: Double, outflow: Double) {
        let transactions = data.transactions.filter { group.accountIDs.contains($0.accountID) }
        let range = getCurrentFiscalRange()
        let filtered = transactions.filter { $0.date >= range.start && $0.date <= range.end }
        
        let inflow = filtered.filter { $0.type == .inflow }.reduce(0) { $0 + $1.amount }
        let outflow = filtered.filter { $0.type == .outflow }.reduce(0) { $0 + $1.amount }
        return (inflow, outflow)
    }

    private func getCurrentFiscalRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startComp = DateComponents(year: components.year, month: components.month, day: fiscalStartDay)
        var start = calendar.date(from: startComp) ?? Date()
        if Date() < start { start = calendar.date(byAdding: .month, value: -1, to: start) ?? start }
        let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? Date()
        return (start, end)
    }
}
