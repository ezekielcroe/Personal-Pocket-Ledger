import SwiftUI

struct AccountsListView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    @State private var showingAddSheet = false
    @State private var accountToEdit: Account?
    
    // Group Management State
    @State private var showingGroupSheet = false
    @State private var groupToEdit: AccountGroup? = nil
    
    // MARK: - Expansion States
    // Default main sections to expanded (true), archived to collapsed (false)
    @State private var isDebitExpanded = true
    @State private var isGoalsExpanded = true
    @State private var isBudgetsExpanded = true
    @State private var isDebtsExpanded = true
    @State private var isGroupsExpanded = true
    @State private var isArchivedExpanded = false

    // MARK: - Filtered Lists
    
    /// Debit accounts without target (Cash, Checking) - Active only
    private var debitAccounts: [Account] {
        data.accounts
            .filter { $0.accountType == .debit && !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Debit accounts with target (Savings Goals) - Active only
    private var goalAccounts: [Account] {
        data.accounts
            .filter { $0.accountType == .goal && !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Credit accounts with target > 0 (Budget Envelopes) - Active only
    private var budgetAccounts: [Account] {
        data.accounts
            .filter { $0.accountType == .budget && !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Credit accounts with nil or 0 target (Debt/Loans) - Active only
    private var debtAccounts: [Account] {
        data.accounts
            .filter { $0.accountType == .debt && !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Archived accounts
    private var archivedAccounts: [Account] {
        data.accounts
            .filter { $0.isArchived }
            .sorted { ($0.archivedDate ?? Date.distantPast) > ($1.archivedDate ?? Date.distantPast) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    if data.accounts.isEmpty && data.accountGroups.isEmpty {
                        Text("No accounts yet. Tap + to add one.")
                            .foregroundColor(.secondary)
                            .padding()
                    }

                    // SECTION 1: DEBIT
                    if !debitAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isDebitExpanded,
                            content: {
                                ForEach(debitAccounts) { account in
                                    accountRowLink(for: account)
                                }
                            },
                            label: { headerLabel(title: "Debit", count: debitAccounts.count) }
                        )
                    }

                    // SECTION 2: GOALS
                    if !goalAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isGoalsExpanded,
                            content: {
                                ForEach(goalAccounts) { account in
                                    accountRowLink(for: account)
                                }
                            },
                            label: { headerLabel(title: "Goals", count: goalAccounts.count) }
                        )
                    }
                    
                    // SECTION 3: BUDGETS
                    if !budgetAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isBudgetsExpanded,
                            content: {
                                ForEach(budgetAccounts) { account in
                                    accountRowLink(for: account)
                                }
                            },
                            label: { headerLabel(title: "Budgets", count: budgetAccounts.count) }
                        )
                    }
                    
                    // SECTION 4: DEBTS
                    if !debtAccounts.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isDebtsExpanded,
                            content: {
                                ForEach(debtAccounts) { account in
                                    accountRowLink(for: account)
                                }
                            },
                            label: { headerLabel(title: "Debts", count: debtAccounts.count) }
                        )
                    }
                    
                    // SECTION 5: ACCOUNT GROUPS
                    if !data.accountGroups.isEmpty {
                        DisclosureGroup(
                            isExpanded: $isGroupsExpanded,
                            content: {
                                ForEach(data.accountGroups) { group in
                                    NavigationLink(destination: AccountGroupDetailView(group: group)) {
                                        HStack {
                                            Image(systemName: "folder")
                                                .foregroundColor(.blue)
                                            Text(group.name)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(data.balance(for: group).formattedCurrency(symbol: currencySymbol))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button { groupToEdit = group } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { data.deleteAccountGroup(group) } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            },
                            label: { headerLabel(title: "Groups", count: data.accountGroups.count) }
                        )
                    }
                    
                    // SECTION 6: ARCHIVED (Separated at bottom)
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
                                                    .strikethrough()
                                                
                                                HStack(spacing: 4) {
                                                    Image(systemName: "archivebox.fill")
                                                        .font(.caption2)
                                                    Text("Archived")
                                                        .font(.caption)
                                                }
                                                .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                                                .foregroundColor(.secondary)
                                                .opacity(0.6)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { data.deleteAccount(account) } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            },
                            label: { headerLabel(title: "Archived", count: archivedAccounts.count) }
                        )
                    }

                    // Footer spacer for FAB visibility
                    Color.clear.frame(height: 80).listRowBackground(Color.clear)
                }
                
                // Multi-Action FAB
                Menu {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("New Account", systemImage: "plus")
                    }
                    
                    Button {
                        showingGroupSheet = true
                    } label: {
                        Label("New Account Group", systemImage: "folder.badge.plus")
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
                // COLLAPSE/EXPAND ALL BUTTON
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        toggleAllSections()
                    } label: {
                        // Dynamic icon: If most are expanded, show collapse icon.
                        let anyExpanded = isDebitExpanded || isGoalsExpanded || isBudgetsExpanded || isDebtsExpanded || isGroupsExpanded
                        Image(systemName: anyExpanded ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            .font(.subheadline)
                    }
                }
            }
            // Sheets
            .sheet(isPresented: $showingAddSheet) {
                AddAccountView()
            }
            .sheet(item: $accountToEdit) { account in
                EditAccountView(account: account)
            }
            .sheet(isPresented: $showingGroupSheet) {
                AddAccountGroupView()
            }
            .sheet(item: $groupToEdit) { group in
                AddAccountGroupView(groupToEdit: group)
            }
        }
    }
    
    // MARK: - Logic
    
    private func toggleAllSections() {
        withAnimation {
            // Logic: If ANY of the main sections are expanded, collapse all.
            // If ALL are collapsed, expand all.
            let anyExpanded = isDebitExpanded || isGoalsExpanded || isBudgetsExpanded || isDebtsExpanded || isGroupsExpanded
            
            let newState = !anyExpanded
            isDebitExpanded = newState
            isGoalsExpanded = newState
            isBudgetsExpanded = newState
            isDebtsExpanded = newState
            isGroupsExpanded = newState
            
            // We usually keep archived collapsed unless manually opened, so we don't toggle it here
            // to avoid cluttering the view when "Expanding All".
        }
    }

    // MARK: - View Builders
    
    private func headerLabel(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
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
            Button {
                accountToEdit = account
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                data.deleteAccount(account)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Enhanced Account Row

struct AccountRow: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            // VISUAL: Account Type Icon
            AccountTypeIcon(type: account.accountType, size: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.headline)
                    
                    // VISUAL: Status Badge
                    if let badge = account.statusBadge(balance: currentBalance) {
                        AccountStatusBadgeView(badge: badge)
                    }
                }
                
                // Type-specific subtitle
                Text(accountTypeLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Balance Display Logic (Type-Specific)
            balanceView
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Balance View
    
    @ViewBuilder
    private var balanceView: some View {
        switch account.accountType {
        case .debit:
            // Simple balance
            Text(currentBalance.formattedCurrency(symbol: currencySymbol))
                .foregroundColor(balanceColor)
                
        case .goal:
            // Progress format: Current / Target
            if let target = account.targetAmount {
                let isMet = currentBalance >= target
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(currentBalance.formattedCurrency(symbol: currencySymbol)) / \(target.formattedCurrency(symbol: currencySymbol))")
                        .foregroundColor(isMet ? .green : .primary)
                        .fontWeight(isMet ? .semibold : .regular)
                    
                    // Progress percentage
                    let percentage = min((currentBalance / target) * 100, 100)
                    Text("\(Int(percentage))%")
                        .font(.caption2)
                        .foregroundColor(isMet ? .green : .secondary)
                }
            }
            
        case .budget:
            // Spending over Budget format: Spent / Budget
            if let target = account.targetAmount {
                let isOverBudget = currentBalance > target
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(currentBalance.formattedCurrency(symbol: currencySymbol)) / \(target.formattedCurrency(symbol: currencySymbol))")
                        .foregroundColor(isOverBudget ? .red : .primary)
                        .fontWeight(isOverBudget ? .semibold : .regular)
                    
                    // Percentage indicator
                    let percentage = (currentBalance / target) * 100
                    Text("\(Int(percentage))% used")
                        .font(.caption2)
                        .foregroundColor(isOverBudget ? .red : .secondary)
                }
            }
            
        case .debt:
            // Debt balance (amount owed)
            Text(currentBalance.formattedCurrency(symbol: currencySymbol))
                .foregroundColor(currentBalance > 0 ? .orange : .green)
                .fontWeight(currentBalance > 0 ? .semibold : .regular)
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentBalance: Double {
        data.balance(for: account)
    }
    
    /// Returns the appropriate label based on account type
    private var accountTypeLabel: String {
        account.accountType.rawValue.capitalized + " Account"
    }
    
    /// Balance text color based on account type and status
    private var balanceColor: Color {
        switch account.accountType {
        case .debit:
            // Debit accounts: Negative balance = overdrawn
            return currentBalance < 0 ? .red : .primary
            
        case .goal:
            // Goals: No special color for simple balance
            return .primary
            
        case .budget:
            // Budgets: Already handled in balance view
            return .primary
            
        case .debt:
            // Debts: Already handled in balance view
            return .primary
        }
    }
}
