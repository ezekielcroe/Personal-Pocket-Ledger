import SwiftUI

struct AccountsListView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    @State private var showingAddSheet = false
    @State private var accountToEdit: Account?
    
    // Group Management State
    @State private var showingGroupSheet = false
    @State private var groupToEdit: AccountGroup?

    // MARK: - Filtered Lists
    
    private var debitAccounts: [Account] {
        data.accounts
            .filter { !$0.isCredit }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var creditAccounts: [Account] {
        data.accounts
            .filter { $0.isCredit }
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

                    // 1. DEBIT SECTION
                    if !debitAccounts.isEmpty {
                        Section(header: Text("Debit Accounts")) {
                            ForEach(debitAccounts) { account in
                                accountRowLink(for: account)
                            }
                        }
                    }

                    // 2. CREDIT SECTION
                    if !creditAccounts.isEmpty {
                        Section(header: Text("Credit Accounts")) {
                            ForEach(creditAccounts) { account in
                                accountRowLink(for: account)
                            }
                        }
                    }
                    
                    // 3. ACCOUNT GROUPS SECTION
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
                
                // NEW: Multi-Action FAB
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
                
                // Show "Goal Account" label if it has a target
                if let _ = account.targetAmount {
                    Text("Target Account")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text(account.isCredit ? "Credit Account" : "Debit Account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            
            // NEW: Display Logic
            if let target = account.targetAmount, target > 0 {
                let current = data.balance(for: account)
                let isMet = current >= target
                
                Text("\(current.formattedCurrency(symbol: currencySymbol)) / \(target.formattedCurrency(symbol: currencySymbol))")
                    .foregroundColor(isMet ? .green : .primary) // Green if met
                    .fontWeight(isMet ? .bold : .regular)      // Bold if met
            } else {
                // Standard Display
                Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                    .foregroundColor(balanceColor)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var balanceColor: Color {
        if account.isCredit {
            return .orange
        } else {
            return data.balance(for: account) < 0 ? .red : .primary
        }
    }
}
