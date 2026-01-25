import SwiftUI

struct AddAccountGroupView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    // Optional: If editing, pass the existing group
    let groupToEdit: AccountGroup?
    
    @State private var name: String
    @State private var selectedAccountIDs: Set<UUID>
    @State private var searchText: String = ""
    
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    // MARK: - Focus State
    enum Field {
        case name
        case search
    }
    @FocusState private var focusedField: Field?
    
    // MARK: - Explicit Initializer
    init(groupToEdit: AccountGroup? = nil) {
        self.groupToEdit = groupToEdit
        
        if let group = groupToEdit {
            _name = State(initialValue: group.name)
            _selectedAccountIDs = State(initialValue: Set(group.accountIDs))
        } else {
            _name = State(initialValue: "")
            _selectedAccountIDs = State(initialValue: [])
        }
    }
    
    // MARK: - Filter Logic
    var filteredAccounts: [Account] {
        let all = data.accounts
        
        let filtered = searchText.isEmpty ? all : all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Sort by: 1) Account Type, 2) Name (alphabetical)
        return filtered.sorted { lhs, rhs in
            // Primary sort: Account type order (Debit, Goal, Budget, Debt)
            let typeOrder: [AccountType] = [.debit, .goal, .budget, .debt]
            let lhsIndex = typeOrder.firstIndex(of: lhs.accountType) ?? 999
            let rhsIndex = typeOrder.firstIndex(of: rhs.accountType) ?? 999
            
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            
            // Secondary sort: Alphabetical by name
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    // MARK: - Grouped Accounts
    private var accountsByType: [(type: AccountType, accounts: [Account])] {
        let typeOrder: [AccountType] = [.debit, .goal, .budget, .debt]
        
        return typeOrder.compactMap { type in
            let accountsOfType = filteredAccounts.filter { $0.accountType == type }
            return accountsOfType.isEmpty ? nil : (type, accountsOfType)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Name Section
                Section(header: Text("Group Name")) {
                    TextField("E.g., Liquid Cash, Travel Fund", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .search
                        }
                }
                
                // MARK: - Search Section
                Section(header: Text("Include Accounts")) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Filter accounts...", text: $searchText)
                            .focused($focusedField, equals: .search)
                            .submitLabel(searchText.isEmpty ? .done : (filteredAccounts.count == 1 ? .join : .search))
                            .onSubmit {
                                handleSearchSubmit()
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // MARK: - Account List (Grouped by Type)
                if filteredAccounts.isEmpty {
                    Section {
                        Text("No accounts found")
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Group accounts by type for visual clarity
                    ForEach(accountsByType, id: \.type) { section in
                        Section(header: Text(section.type.rawValue)) {
                            ForEach(section.accounts) { account in
                                Button {
                                    toggleSelection(for: account)
                                } label: {
                                    HStack(spacing: 12) {
                                        AccountTypeIcon(type: account.accountType, size: 32)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(account.name)
                                                    .foregroundColor(.primary)
                                                
                                                if let badge = account.statusBadge(balance: data.balance(for: account)) {
                                                    AccountStatusBadgeView(badge: badge)
                                                }
                                            }
                                            
                                            Text(account.accountType.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                                            .font(.subheadline)
                                            .foregroundColor(balanceColor(for: account))
                                        
                                        if selectedAccountIDs.contains(account.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .fontWeight(.bold)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.secondary.opacity(0.3))
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .formToolbar(
                title: groupToEdit == nil ? "New Group" : "Edit Group",
                canSave: canSave,
                onSave: { saveGroup() },
                onCancel: { dismiss() }
            )
            .onAppear {
                if groupToEdit == nil {
                    focusedField = .name
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedAccountIDs.isEmpty
    }
    
    private func toggleSelection(for account: Account) {
        if selectedAccountIDs.contains(account.id) {
            selectedAccountIDs.remove(account.id)
        } else {
            selectedAccountIDs.insert(account.id)
        }
    }
    
    private func handleSearchSubmit() {
        if searchText.isEmpty {
            if canSave {
                saveGroup()
            }
        } else if filteredAccounts.count == 1 {
            if let account = filteredAccounts.first {
                toggleSelection(for: account)
                searchText = ""
            }
        }
    }
    
    private func saveGroup() {
        if var group = groupToEdit {
            group.name = name
            group.accountIDs = Array(selectedAccountIDs)
            data.updateAccountGroup(group)
        } else {
            data.addAccountGroup(name: name, accountIDs: Array(selectedAccountIDs))
        }
        dismiss()
    }
    
    // MARK: - Styling Helpers
    
    private func balanceColor(for account: Account) -> Color {
        let balance = data.balance(for: account)
        
        switch account.accountType {
        case .debit:
            return balance < 0 ? .red : .primary
        case .goal:
            if let target = account.targetAmount, balance >= target {
                return .green
            }
            return .primary
        case .budget:
            if let target = account.targetAmount, balance > target {
                return .red
            }
            return .primary
        case .debt:
            return balance > 0 ? .orange : .green
        }
    }
}
