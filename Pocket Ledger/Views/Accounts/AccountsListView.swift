import SwiftUI

struct AccountsListView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    @State private var showingAddSheet = false
    @State private var accountToEdit: Account?
    
    // Group Management State
    @State private var showingGroupSheet = false
    @State private var groupToEdit: AccountGroup? = nil

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

                    // SECTION 1: DEBIT (Cash/Checking)
                    if !debitAccounts.isEmpty {
                        Section(header: Text("Debit")) {
                            ForEach(debitAccounts) { account in
                                accountRowLink(for: account)
                            }
                        }
                    }

                    // SECTION 2: GOALS (Savings Targets)
                    if !goalAccounts.isEmpty {
                        Section(header: Text("Goals")) {
                            ForEach(goalAccounts) { account in
                                accountRowLink(for: account)
                            }
                        }
                    }
                    
                    // SECTION 3: BUDGETS (Spending Envelopes)
                    if !budgetAccounts.isEmpty {
                        Section(header: Text("Budgets")) {
                            ForEach(budgetAccounts) { account in
                                accountRowLink(for: account)
                            }
                        }
                    }
                    
                    // SECTION 4: DEBTS (Credit Cards/Loans)
                    if !debtAccounts.isEmpty {
                        Section(header: Text("Debts")) {
                            ForEach(debtAccounts) { account in
                                accountRowLink(for: account)
                            }
                        }
                    }
                    
                    // SECTION 5: ACCOUNT GROUPS (Virtual Aggregates)
                    if !data.accountGroups.isEmpty {
                        Section(header: Text("Account Groups")) {
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
                                    Button {
                                        groupToEdit = group
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        data.deleteAccountGroup(group)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    // SECTION 6: ARCHIVED ACCOUNTS
                    if !archivedAccounts.isEmpty {
                        Section(header: Text("Archived")) {
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
                                                
                                                if let archivedDate = account.archivedDate {
                                                    Text("• \(archivedDate.formatted(date: .abbreviated, time: .omitted))")
                                                        .font(.caption2)
                                                }
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
                                    Button(role: .destructive) {
                                        data.deleteAccount(account)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
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

    // MARK: - Row Builder
    
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
