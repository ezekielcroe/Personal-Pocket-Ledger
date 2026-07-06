import SwiftUI

struct AccountsListView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    // MARK: - Navigation State
    @Binding var globalAddAccountTrigger: Bool
    @Binding var globalAddGroupTrigger: Bool
    
    // Local State for Editing
    @State private var accountToEdit: Account?
    @State private var groupToEdit: AccountGroup? = nil
    
    // NEW: State for Reconcile Sheet
    @State private var showingReconcileSheet = false
    
    // MARK: - Expansion States
    @State private var isDebitExpanded = true
    @State private var isGoalsExpanded = true
    @State private var isBudgetsExpanded = true
    @State private var isDebtsExpanded = true
    @State private var isGroupsExpanded = true
    @State private var isArchivedExpanded = false

    private var debitAccounts: [Account] {
        store.accounts
            .filter { $0.accountType == .debit && !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var goalAccounts: [Account] {
        store.accounts
            .filter { $0.accountType == .goal && !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var budgetAccounts: [Account] {
        store.accounts
            .filter { $0.accountType == .limit && !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var debtAccounts: [Account] {
        store.accounts
            .filter { $0.accountType == .debt && !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var archivedAccounts: [Account] {
        store.accounts
            .filter { $0.isArchived }
            .sorted { ($0.archivedDate ?? Date.distantPast) > ($1.archivedDate ?? Date.distantPast) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    if store.accounts.isEmpty && store.accountGroups.isEmpty {
                        Text("No accounts yet. Tap + to add one.")
                            .foregroundColor(.secondary)
                            .padding()
                    }

                    // SECTION 1: DEBIT
                    if !debitAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isDebitExpanded,
                            content: { ForEach(debitAccounts) { accountRowLink(for: $0) } },
                            label: { headerLabel(title: "Debit accounts", count: debitAccounts.count) }
                        )
                    }

                    // SECTION 2: GOALS
                    if !goalAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isGoalsExpanded,
                            content: { ForEach(goalAccounts) { accountRowLink(for: $0) } },
                            label: { headerLabel(title: "Goal accounts", count: goalAccounts.count) }
                        )
                    }
                    
                    // SECTION 3: BUDGETS
                    if !budgetAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isBudgetsExpanded,
                            content: { ForEach(budgetAccounts) { accountRowLink(for: $0) } },
                            label: { headerLabel(title: "Limit accounts", count: budgetAccounts.count) }
                        )
                    }
                    
                    // SECTION 4: DEBTS
                    if !debtAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isDebtsExpanded,
                            content: { ForEach(debtAccounts) { accountRowLink(for: $0) } },
                            label: { headerLabel(title: "Debt accounts", count: debtAccounts.count) }
                        )
                    }
                    
                    // SECTION 5: ACCOUNT GROUPS
                    if !store.accountGroups.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isGroupsExpanded,
                            content: {
                                ForEach(store.accountGroups) { group in
                                    NavigationLink(destination: AccountGroupDetailView(group: group)) {
                                        HStack {
                                            Image(systemName: "folder")
                                                .foregroundColor(.blue)
                                            Text(group.name)
                                                .fontWeight(.medium)
                                            Spacer()
                                            // Read from cache — O(1) dictionary lookup
                                            Text((store.groupBalances[group.id] ?? 0).formattedCurrency(symbol: currencySymbol))
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button { groupToEdit = group } label: { Label("Edit", systemImage: "pencil") }
                                            .tint(.blue)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { store.deleteAccountGroup(group) } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            },
                            label: { headerLabel(title: "Groups", count: store.accountGroups.count) }
                        )
                    }
                    
                    // SECTION 6: ARCHIVED
                    if !archivedAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isArchivedExpanded,
                            content: {
                                ForEach(archivedAccounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(account.name)
                                                    .font(.headline)
                                                    .foregroundColor(.secondary)
                                                
                                                HStack(spacing: 4) {
                                                    Image(systemName: "archivebox.fill")
                                                        .font(.caption2)
                                                    Text("Archived")
                                                        .font(.caption)
                                                }
                                                .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            // Read from cache — O(1) dictionary lookup
                                            Text((store.balances[account.id] ?? 0).formattedCurrency(symbol: currencySymbol))
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .opacity(0.6)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { store.deleteAccount(account) } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            },
                            label: { headerLabel(title: "Archived", count: archivedAccounts.count) }
                        )
                    }

                    // Footer spacer
                    Color.clear.frame(height: 80).listRowBackground(Color.clear)
                }
                
                // FABs: Reconcile beside the add menu
                HStack(spacing: 14) {
                    Button { showingReconcileSheet = true } label: {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(Color.green))
                            .shadow(radius: 4)
                    }
                    
                    Menu {
                        Button { globalAddAccountTrigger = true } label: { Label("New Account", systemImage: "plus") }
                        Button { globalAddGroupTrigger = true } label: { Label("New Account Group", systemImage: "folder.badge.plus") }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.blue)
                            .shadow(radius: 4)
                    }
                }
                .padding()
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleAllSections) {
                        let anyExpanded = isDebitExpanded || isGoalsExpanded || isBudgetsExpanded || isDebtsExpanded || isGroupsExpanded
                        Image(systemName: anyExpanded ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    }
                }
            }
            .sheet(item: $accountToEdit) { account in
                EditAccountView(account: account)
                    .environmentObject(store)
            }
            .sheet(item: $groupToEdit) { group in
                AddAccountGroupView(groupToEdit: group)
                    .environmentObject(store)
                    .environmentObject(transactionStore)
            }
            .sheet(isPresented: $showingReconcileSheet) {
                NavigationStack {
                    ReconcileSessionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showingReconcileSheet = false }
                            }
                        }
                }
                .environmentObject(store)
                .environmentObject(transactionStore)
            }
        }
    }
    
    private func toggleAllSections() {
        withAnimation {
            let anyExpanded = isDebitExpanded || isGoalsExpanded || isBudgetsExpanded || isDebtsExpanded || isGroupsExpanded
            let newState = !anyExpanded
            isDebitExpanded = newState
            isGoalsExpanded = newState
            isBudgetsExpanded = newState
            isDebtsExpanded = newState
            isGroupsExpanded = newState
        }
    }

    private func headerLabel(title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.headline).foregroundColor(.primary)
            Spacer()
            Text("\(count)")
                .font(.caption).foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    private func accountRowLink(for account: Account) -> some View {
        NavigationLink(destination: AccountDetailView(account: account)) {
            AccountRow(account: account)
        }
        .swipeActions(edge: .leading) {
            Button { accountToEdit = account } label: { Label("Edit", systemImage: "pencil") }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button {
                withAnimation {
                    store.archiveAccount(account)
                }
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.orange)
        }
    }
}

// MARK: - Account Row

struct AccountRow: View {
    // AccountRow now only needs AccountStore — balances come from the cache,
    // so there is no need to observe TransactionStore directly.
    @EnvironmentObject var store: AccountStore
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    let account: Account

    var body: some View {
        HStack(spacing: 8) {
            // 1. LEFT SIDE: Name & Type
            VStack(alignment: .leading, spacing: 3) {
                // Row A: Name + Badge + Reconciliation Dot
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let badge = account.statusBadge(balance: currentBalance) {
                        AccountStatusBadgeView(badge: badge)
                            .scaleEffect(0.75)
                    }
                    
                    // Reconciliation Status Dot
                    if let dotColor = reconciliationColor {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                            .padding(.leading, 2)
                    }
                }
                
                // Row B: Icon + Label
                HStack(spacing: 4) {
                    Image(systemName: account.accountType.icon)
                        .foregroundColor(account.accountType.color)
                    
                    Text(accountTypeLabel)
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            
            Spacer()
            
            // 2. RIGHT SIDE: Balance
            balanceView
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Reconciliation Logic
    private var reconciliationColor: Color? {
        guard let date = account.lastReconciledDate else { return nil }
        
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        
        if days < 7 { return .green }
        if days < 30 { return .yellow }
        return .red
    }
    
    // MARK: - Balance View
    
    @ViewBuilder
    private var balanceView: some View {
        switch account.accountType {
        case .debit:
            Text(currentBalance.formattedCurrency(symbol: currencySymbol))
                .foregroundColor(balanceColor)
                
        case .goal:
            if let target = account.targetAmount {
                let isMet = currentBalance >= target
                VStack(alignment: .trailing, spacing: 0) {
                    Text(currentBalance.formattedCurrency(symbol: currencySymbol))
                        .foregroundColor(isMet ? .green : .primary)
                    
                    Text("of \(target.formattedCurrency(symbol: currencySymbol))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                 Text(currentBalance.formattedCurrency(symbol: currencySymbol))
            }
            
        case .limit:
            if let target = account.targetAmount {
                let isOverBudget = currentBalance > target
                VStack(alignment: .trailing, spacing: 0) {
                    Text(currentBalance.formattedCurrency(symbol: currencySymbol))
                        .foregroundColor(isOverBudget ? .red : .primary)
                    
                    Text("/ \(target.formattedCurrency(symbol: currencySymbol))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(currentBalance.formattedCurrency(symbol: currencySymbol))
            }
            
        case .debt:
            Text(currentBalance.formattedCurrency(symbol: currencySymbol))
                .foregroundColor(currentBalance > 0 ? .orange : .green)
        }
    }
    
    // MARK: - Computed Properties
    
    /// O(1) dictionary lookup from the pre-computed balance cache.
    private var currentBalance: Decimal {
        store.balances[account.id] ?? 0
    }
    
    private var accountTypeLabel: String {
        account.accountType.rawValue.capitalized
    }
    
    private var balanceColor: Color {
        switch account.accountType {
        case .debit:
            return currentBalance < 0 ? .red : .primary
        default:
            return .primary
        }
    }
}
