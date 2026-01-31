import SwiftUI

struct AccountGroupDetailView: View {
    @EnvironmentObject var data: AppData
    let group: AccountGroup
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    @State private var expandedMemberIDs: Set<UUID> = []
    
    var body: some View {
        List {
            // SECTION 1: Total Balance
            Section(header: Text("Total")) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Group Balance")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Text(data.groupBalance(group).formattedCurrency(symbol: currencySymbol))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(totalBalanceColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Nesting depth indicator
                    let depth = data.depth(of: group)
                    if depth > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.forward")
                                .font(.caption2)
                            Text("Nesting depth: \(depth)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            // SECTION 2: Hierarchical Breakdown
            Section(header: HStack {
                Text("Members (\(group.memberIDs.count))")
                Spacer()
                Button(expandedMemberIDs.isEmpty ? "Expand All" : "Collapse All") {
                    toggleAllMembers()
                }
                .font(.caption)
            }, footer: Text(balanceCalculationExplanation)) {
                // REFACTORED: Now uses a struct instead of a recursive function call
                ForEach(data.members(for: group), id: \.id) { member in
                    MemberRowView(
                        member: member,
                        depth: 0,
                        expandedMemberIDs: $expandedMemberIDs
                    )
                }
            }
            
            // SECTION 3: Statistics (This Period)
            Section(header: Text("Statistics")) {
                let totals = calculateGroupMonthlyTotals()
                StatRow(title: "Inflow (This Month)", value: totals.inflow, symbol: currencySymbol, color: .green)
                StatRow(title: "Outflow (This Month)", value: totals.outflow, symbol: currencySymbol, color: .red)
            }
            
            // SECTION 4: Recent Transactions
            Section(header: Text("Recent Transactions (Last 25)")) {
                let recent = recentTransactions
                
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
        .onAppear {
            // Auto-expand first level
            expandedMemberIDs = Set(group.memberIDs.filter { id in
                data.accountGroups.contains(where: { $0.id == id })
            })
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleAllMembers() {
        if expandedMemberIDs.isEmpty {
            // Expand all groups recursively
            expandedMemberIDs = Set(allGroupIDs(in: group))
        } else {
            // Collapse all
            expandedMemberIDs.removeAll()
        }
    }
    
    private func allGroupIDs(in group: AccountGroup) -> [UUID] {
        var result: [UUID] = []
        
        for member in data.members(for: group) {
            if case .group(let childGroup) = member {
                result.append(childGroup.id)
                result.append(contentsOf: allGroupIDs(in: childGroup))
            }
        }
        
        return result
    }
    
    private var totalBalanceColor: Color {
        let total = data.groupBalance(group)
        return total < 0 ? .red : .primary
    }
    
    private var balanceCalculationExplanation: String {
        let allAccountIDs = data.allAccountIDs(in: group)
        let hasDebit = allAccountIDs.contains { id in
            data.accounts.first(where: { $0.id == id })?.isCredit == false
        }
        let hasCredit = allAccountIDs.contains { id in
            data.accounts.first(where: { $0.id == id })?.isCredit == true
        }
        
        if hasDebit && hasCredit {
            return "Group total = Debit accounts (+) minus Credit accounts (−). Groups are calculated recursively."
        } else if hasCredit {
            return "Group total = Sum of all credit balances. Groups are calculated recursively."
        } else {
            return "Group total = Sum of all debit balances. Groups are calculated recursively."
        }
    }
    
    private var recentTransactions: [Transaction] {
        let allAccountIDs = data.allAccountIDs(in: group)
        
        return data.transactions
            .filter { allAccountIDs.contains($0.accountID) }
            .sorted { $0.date > $1.date }
            .prefix(25)
            .map { $0 }
    }
    
    // MARK: - Statistics Calculation
    
    private func calculateGroupMonthlyTotals() -> (inflow: Double, outflow: Double) {
        let allAccountIDs = data.allAccountIDs(in: group)
        let transactions = data.transactions.filter { allAccountIDs.contains($0.accountID) }
        
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

// MARK: - Member Row Struct (Fixes Recursive Type Error)

struct MemberRowView: View {
    @EnvironmentObject var data: AppData
    let member: MemberType
    let depth: Int
    @Binding var expandedMemberIDs: Set<UUID>
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    var body: some View {
        switch member {
        case .account(let account):
            accountRow(account)
        case .group(let group):
            groupRow(group)
        }
    }
    
    // MARK: - Account Member Row
    
    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        NavigationLink(destination: AccountDetailView(account: account)) {
            HStack(spacing: 8) {
                // Indentation
                if depth > 0 {
                    indentationView(depth: depth)
                }
                
                // Account icon
                AccountTypeIcon(type: account.accountType, size: 28)
                
                // Account info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(account.name)
                            .font(.body)
                        
                        if let badge = account.statusBadge(balance: data.balance(for: account)) {
                            AccountStatusBadgeView(badge: badge)
                        }
                    }
                    
                    Text(account.accountType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Balance breakdown
                VStack(alignment: .trailing, spacing: 4) {
                    Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(accountBalanceColor(for: account))
                    
                    Text(contributionText(for: account))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Group Member Row (Recursive)
    
    @ViewBuilder
    private func groupRow(_ childGroup: AccountGroup) -> some View {
        VStack(spacing: 0) {
            // Group header (expandable)
            Button {
                toggleExpansion(for: childGroup.id)
            } label: {
                HStack(spacing: 8) {
                    // Indentation
                    if depth > 0 {
                        indentationView(depth: depth)
                    }
                    
                    // Expansion chevron
                    Image(systemName: expandedMemberIDs.contains(childGroup.id) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    // Group icon
                    Image(systemName: "folder.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                        .frame(width: 28, height: 28)
                    
                    // Group info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(childGroup.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                        
                        Text("\(childGroup.memberIDs.count) members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Group balance
                    Text(data.groupBalance(childGroup).formattedCurrency(symbol: currencySymbol))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            
            // Expanded children (recursive)
            // This is now safe because MemberRowView is a struct (concrete type)
            if expandedMemberIDs.contains(childGroup.id) {
                ForEach(data.members(for: childGroup), id: \.id) { nestedMember in
                    MemberRowView(
                        member: nestedMember,
                        depth: depth + 1,
                        expandedMemberIDs: $expandedMemberIDs
                    )
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func indentationView(depth: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<depth, id: \.self) { _ in
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 2, height: 24)
                    .padding(.leading, 8)
            }
        }
    }
    
    private func toggleExpansion(for id: UUID) {
        if expandedMemberIDs.contains(id) {
            expandedMemberIDs.remove(id)
        } else {
            expandedMemberIDs.insert(id)
        }
    }
    
    private func accountBalanceColor(for account: Account) -> Color {
        let balance = data.balance(for: account)
        
        if account.isCredit {
            if balance > account.initialAmount * 0.9 {
                return .red
            } else if balance > account.initialAmount * 0.7 {
                return .orange
            }
        } else {
            if balance < 0 {
                return .red
            }
        }
        return .primary
    }
    
    private func contributionText(for account: Account) -> String {
        let balance = data.balance(for: account)
        
        if account.isCredit {
            return "(\(balance.formattedCurrency(symbol: currencySymbol)))"
        } else {
            return "+\(balance.formattedCurrency(symbol: currencySymbol))"
        }
    }
}
