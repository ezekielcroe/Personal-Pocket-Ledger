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
    
    /// Debit accounts without target (Cash, Checking)
    private var debitAccounts: [Account] {
        data.accounts
            .filter { !$0.isCredit && $0.targetAmount == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Credit accounts without target (Credit Cards, Loans)
    private var creditAccounts: [Account] {
        data.accounts
            .filter { $0.isCredit && $0.targetAmount == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Debit accounts with target (Savings Goals)
    private var goalAccounts: [Account] {
        data.accounts
            .filter { !$0.isCredit && $0.targetAmount != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Credit accounts with target (Budget Envelopes)
    private var budgetAccounts: [Account] {
        data.accounts
            .filter { $0.isCredit && $0.targetAmount != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

                    // SECTION 2: CREDIT (Credit Cards/Loans)
                    if !creditAccounts.isEmpty {
                        Section(header: Text("Credit")) {
                            ForEach(creditAccounts) { account in
                                accountRowLink(for: account)
                            }
                        }
                    }
                    
                    // SECTION 3: GOALS (Savings Targets)
                    if !goalAccounts.isEmpty {
                        Section(header: Text("Goals")) {
                            ForEach(goalAccounts) { account in
                                accountRowLink(for: account)
                            }
                        }
                    }
                    
                    // SECTION 4: BUDGETS (Spending Envelopes)
                    if !budgetAccounts.isEmpty {
                        Section(header: Text("Budgets")) {
                            ForEach(budgetAccounts) { account in
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

// MARK: - Helper Views

struct AccountRow: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    let account: Account

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name)
                    .font(.headline)
                
                // Type-specific subtitle
                Text(accountTypeLabel)
                    .font(.caption)
                    .foregroundColor(accountTypeLabelColor)
            }
            Spacer()
            
            // Balance Display Logic (Type-Specific)
            switch account.accountType {
            case .debit:
                // Simple balance
                Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                    .foregroundColor(balanceColor)
                
            case .goal:
                // Progress format: Current / Target
                if let target = account.targetAmount {
                    let current = data.balance(for: account)
                    let isMet = current >= target
                    
                    Text("\(current.formattedCurrency(symbol: currencySymbol)) / \(target.formattedCurrency(symbol: currencySymbol))")
                        .foregroundColor(isMet ? .green : .primary)
                        .fontWeight(isMet ? .bold : .regular)
                }
                
            case .budget:
                // Spending over Budget format: Spent / Budget
                if let target = account.targetAmount {
                    let spent = data.balance(for: account)
                    let isOverBudget = spent > target
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(spent.formattedCurrency(symbol: currencySymbol)) / \(target.formattedCurrency(symbol: currencySymbol))")
                            .foregroundColor(isOverBudget ? .red : .primary)
                            .fontWeight(isOverBudget ? .bold : .regular)
                        
                        // Percentage indicator
                        let percentage = (spent / target) * 100
                        Text("\(Int(percentage))% used")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
            case .debt:
                // Debt balance (amount owed)
                let balance = data.balance(for: account)
                Text(balance.formattedCurrency(symbol: currencySymbol))
                    .foregroundColor(balance > 0 ? .orange : .green)
                    .fontWeight(balance > 0 ? .bold : .regular)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    /// Returns the appropriate label based on account type
    private var accountTypeLabel: String {
        account.accountType.rawValue + " Account"
    }
    
    /// Color coding for account type labels
    private var accountTypeLabelColor: Color {
        switch account.accountType {
        case .debit:  return .secondary
        case .goal:   return .blue
        case .budget: return .purple
        case .debt:   return .orange
        }
    }
    
    /// Balance text color based on account type and status
    private var balanceColor: Color {
        let balance = data.balance(for: account)
        
        if account.isCredit {
            // Credit accounts: Higher balance = more debt/spending
            // Warn if approaching or exceeding initial amount
            if balance > account.initialAmount * 0.9 {
                return .red
            } else if balance > account.initialAmount * 0.7 {
                return .orange
            } else {
                return .primary
            }
        } else {
            // Debit accounts: Negative balance = overdrawn
            return balance < 0 ? .red : .primary
        }
    }
}
