import SwiftUI

struct AccountGroupDetailView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    
    let group: AccountGroup
    
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    @State private var expandedMemberIDs: Set<UUID> = []
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
    // NEW: Live Group object for reactive updates
    private var liveGroup: AccountGroup {
        accountStore.accountGroups.first(where: { $0.id == group.id }) ?? group
    }
    
    var body: some View {
        List {
            // SECTION 1: Total Balance
            Section(header: Text("Total")) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Group Balance").font(.headline)
                        Spacer()
                    }
                    Text(accountStore.groupBalance(liveGroup, transactions: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(totalBalanceColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    let depth = accountStore.depth(of: liveGroup)
                    if depth > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.forward").font(.caption2)
                            Text("Nesting depth: \(depth)").font(.caption)
                        }
                        .foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            // SECTION 2: Hierarchical Breakdown
            Section(header: HStack {
                Text("Members (\(liveGroup.memberIDs.count))")
                Spacer()
                Button(expandedMemberIDs.isEmpty ? "Expand All" : "Collapse All") { toggleAllMembers() }
                .font(.caption)
            }, footer: Text(balanceCalculationExplanation)) {
                ForEach(accountStore.members(for: liveGroup), id: \.id) { member in
                    MemberRowView(member: member, depth: 0, expandedMemberIDs: $expandedMemberIDs)
                }
            }
            
            // SECTION 3: Statistics
            Section(header: Text("Statistics")) {
                let totals = calculateGroupMonthlyTotals()
                StatRow(title: "Inflow (This Month)", value: totals.inflow, symbol: currencySymbol, color: .green)
                StatRow(title: "Outflow (This Month)", value: totals.outflow, symbol: currencySymbol, color: .red)
            }
            
            // SECTION 4: Recent Transactions
            Section(header: Text("Recent Transactions (Last 25)")) {
                let recent = recentTransactions
                if recent.isEmpty {
                    Text("No transactions in this group.").foregroundColor(.secondary)
                } else {
                    ForEach(recent) { tx in
                        NavigationLink(destination: TransactionDetailView(transaction: tx)) {
                            TransactionRow(transaction: tx)
                        }
                    }
                }
            }
        }
        .navigationTitle(liveGroup.name)
        // NEW: Actions Menu
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Group", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Group", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddAccountGroupView(groupToEdit: liveGroup)
        }
        .alert("Delete Group", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                accountStore.deleteAccountGroup(liveGroup)
                dismiss()
            }
        } message: {
            Text("Delete this group? Accounts inside it will not be deleted, they will just be ungrouped.")
        }
        .onAppear {
            expandedMemberIDs = Set(liveGroup.memberIDs.filter { id in accountStore.accountGroups.contains(where: { $0.id == id }) })
        }
    }
    
    // [Helper functions remain unchanged: toggleAllMembers, calculateGroupMonthlyTotals, etc.]
    private func toggleAllMembers() {
        if expandedMemberIDs.isEmpty { expandedMemberIDs = Set(allGroupIDs(in: liveGroup)) }
        else { expandedMemberIDs.removeAll() }
    }
    
    private func allGroupIDs(in group: AccountGroup) -> [UUID] {
        var result: [UUID] = []
        for member in accountStore.members(for: group) {
            if case .group(let childGroup) = member {
                result.append(childGroup.id)
                result.append(contentsOf: allGroupIDs(in: childGroup))
            }
        }
        return result
    }
    
    private var totalBalanceColor: Color {
        accountStore.groupBalance(liveGroup, transactions: transactionStore.transactions) < 0 ? .red : .primary
    }
    
    private var balanceCalculationExplanation: String {
        let ids = accountStore.allAccountIDs(in: liveGroup)
        let hasDebit = ids.contains { id in accountStore.accounts.first(where: { $0.id == id })?.isCredit == false }
        let hasCredit = ids.contains { _ in accountStore.accounts.first(where: { $0.id == $0.id })?.isCredit == true }
        if hasDebit && hasCredit { return "Group total = Debit accounts (+) minus Credit accounts (−)." }
        else if hasCredit { return "Group total = Sum of all credit balances." }
        else { return "Group total = Sum of all debit balances." }
    }
    
    private var recentTransactions: [Transaction] {
        let ids = accountStore.allAccountIDs(in: liveGroup)
        return transactionStore.transactions
            .filter { ids.contains($0.accountID) }
            .sorted { $0.date > $1.date }
            .prefix(25)
            .map { $0 }
    }
    
    private func calculateGroupMonthlyTotals() -> (inflow: Decimal, outflow: Decimal) {
        let ids = accountStore.allAccountIDs(in: liveGroup)
        let transactions = transactionStore.transactions.filter { ids.contains($0.accountID) }
        let range = getCurrentFiscalRange()
        let filtered = transactions.filter { $0.date >= range.start && $0.date <= range.end }
        return (filtered.filter { $0.type == .inflow }.reduce(0) { $0 + $1.amount },
                filtered.filter { $0.type == .outflow }.reduce(0) { $0 + $1.amount })
    }

    private func getCurrentFiscalRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        var start = calendar.date(from: DateComponents(year: components.year, month: components.month, day: fiscalStartDay)) ?? Date()
        if Date() < start { start = calendar.date(byAdding: .month, value: -1, to: start) ?? start }
        let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? Date()
        return (start, end)
    }
}

// MARK: - Member Row Struct (Fixes Recursive Type Error)

struct MemberRowView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    
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
                        
                        if let badge = account.statusBadge(balance: accountStore.balance(for: account, transactions: transactionStore.transactions)) {
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
                    Text(accountStore.balance(for: account, transactions: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
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
                    Text(accountStore.groupBalance(childGroup, transactions: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
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
                ForEach(accountStore.members(for: childGroup), id: \.id) { nestedMember in
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
        let balance = accountStore.balance(for: account, transactions: transactionStore.transactions)
        
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
        let balance = accountStore.balance(for: account, transactions: transactionStore.transactions)
        
        if account.isCredit {
            return "(\(balance.formattedCurrency(symbol: currencySymbol)))"
        } else {
            return "+\(balance.formattedCurrency(symbol: currencySymbol))"
        }
    }
}
