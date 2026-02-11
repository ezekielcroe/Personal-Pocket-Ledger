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
            .filter { $0.accountType == .budget && !$0.isArchived }
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
                    // ... [List Content remains unchanged] ...
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
                            label: { headerLabel(title: "Debit", count: debitAccounts.count) }
                        )
                    }

                    // SECTION 2: GOALS
                    if !goalAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isGoalsExpanded,
                            content: { ForEach(goalAccounts) { accountRowLink(for: $0) } },
                            label: { headerLabel(title: "Goals", count: goalAccounts.count) }
                        )
                    }
                    
                    // SECTION 3: BUDGETS
                    if !budgetAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isBudgetsExpanded,
                            content: { ForEach(budgetAccounts) { accountRowLink(for: $0) } },
                            label: { headerLabel(title: "Budgets", count: budgetAccounts.count) }
                        )
                    }
                    
                    // SECTION 4: DEBTS
                    if !debtAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isDebtsExpanded,
                            content: { ForEach(debtAccounts) { accountRowLink(for: $0) } },
                            label: { headerLabel(title: "Debts", count: debtAccounts.count) }
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
                                            Text(store.groupBalance(group, transactions: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
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
                                            Text(store.balance(for: account, transactions: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
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
                
                // FAB Menu (UPDATED)
                Menu {
                    Button { globalAddAccountTrigger = true } label: { Label("New Account", systemImage: "plus") }
                    Button { globalAddGroupTrigger = true } label: { Label("New Account Group", systemImage: "folder.badge.plus") }
                    
                    Divider()
                    
                    // NEW: Reconcile Action
                    Button { showingReconcileSheet = true } label: {
                        Label("Reconcile Accounts", systemImage: "checkmark.seal")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
                }
                .padding()
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { toggleAllSections() } label: {
                        let anyExpanded = isDebitExpanded || isGoalsExpanded || isBudgetsExpanded || isDebtsExpanded || isGroupsExpanded
                        Image(systemName: anyExpanded ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            .font(.subheadline)
                    }
                }
            }
            .sheet(isPresented: $globalAddAccountTrigger) { AddAccountView() }
            .sheet(isPresented: $globalAddGroupTrigger) { AddAccountGroupView() }
            .sheet(item: $accountToEdit) { account in EditAccountView(account: account) }
            .sheet(item: $groupToEdit) { group in AddAccountGroupView(groupToEdit: group) }
            
            // NEW: Reconcile Sheet
            .sheet(isPresented: $showingReconcileSheet) {
                ReconcileSelectionView()
                    .environmentObject(store)
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
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
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
                    
                    // NEW: Reconciliation Status Dot
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
        
        if days < 7 { return .green }      // Verified recently
        if days < 30 { return .yellow }    // Stale
        return .red                        // Needs Attention
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
            
        case .budget:
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
    
    private var currentBalance: Decimal {
        store.balance(for: account, transactions: transactionStore.transactions)
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
