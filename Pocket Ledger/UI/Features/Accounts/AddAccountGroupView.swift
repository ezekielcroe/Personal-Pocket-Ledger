import SwiftUI

struct AddAccountGroupView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    
    let groupToEdit: AccountGroup?
    
    @State private var name: String
    @State private var selectedMemberIDs: Set<UUID>
    @State private var searchText: String = ""
    
    @State private var showingCycleAlert = false
    @State private var cycleAlertMessage = ""
    
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    // MARK: - Focus State
    enum Field {
        case name
        case search
    }
    @FocusState private var focusedField: Field?
    
    // MARK: - Member Display Mode
    enum DisplayMode: String, CaseIterable {
        case all = "All"
        case accounts = "Accounts Only"
        case groups = "Groups Only"
    }
    @State private var displayMode: DisplayMode = .all
    
    // MARK: - Explicit Initializer
    init(groupToEdit: AccountGroup? = nil) {
        self.groupToEdit = groupToEdit
        
        if let group = groupToEdit {
            _name = State(initialValue: group.name)
            _selectedMemberIDs = State(initialValue: Set(group.memberIDs))
        } else {
            _name = State(initialValue: "")
            _selectedMemberIDs = State(initialValue: [])
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Name Section
                Section(header: Text("Group Name")) {
                    TextField("e.g., Total Cash, Net Worth", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .search
                        }
                }
                
                // MARK: - Members Section
                Section(header: memberSectionHeader) {
                    if availableAccounts.isEmpty && availableGroups.isEmpty {
                        Text("No accounts or groups available.")
                            .foregroundColor(.secondary)
                    } else {
                        memberList
                    }
                }
            }
            .formToolbar(
                title: groupToEdit == nil ? "New Group" : "Edit Group",
                canSave: canSave,
                onSave: { saveGroup() },
                onCancel: { dismiss() }
            )
            .alert("Cannot Add Group", isPresented: $showingCycleAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(cycleAlertMessage)
            }
            .onAppear {
                if groupToEdit == nil {
                    focusedField = .name
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var memberSectionHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Members")
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search accounts...", text: $searchText)
                    .focused($focusedField, equals: .search)
                    .submitLabel(.done)
                    .onSubmit { handleSearchSubmit() }
                
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            
            // Filter Segments
            Picker("Display", selection: $displayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.bottom, 4)
    }
    
    private var memberList: some View {
        Group {
            // 1. Groups List
            if displayMode != .accounts {
                ForEach(filteredGroups) { group in
                    Button {
                        attemptToggleGroup(group)
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.purple)
                                    .font(.caption)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(group.name)
                                    .foregroundColor(.primary)
                                Text("\(group.memberIDs.count) members")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedMemberIDs.contains(group.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary.opacity(0.3))
                                    .font(.title3)
                            }
                        }
                    }
                }
            }
            
            // 2. Accounts List
            if displayMode != .groups {
                ForEach(filteredAccounts) { account in
                    let isIndirect = indirectlySelectedMemberIDs.contains(account.id)
                    let isDirect = selectedMemberIDs.contains(account.id)
                    
                    Button {
                        if !isIndirect {
                            toggleSelection(for: account.id)
                        }
                    } label: {
                        HStack {
                            AccountTypeIcon(type: account.accountType, size: 32)
                            
                            VStack(alignment: .leading) {
                                Text(account.name)
                                    .foregroundColor(isIndirect ? .secondary : .primary)
                                
                                if isIndirect {
                                    Text("Included via group")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .italic()
                                } else {
                                    Text(accountStore.balance(for: account, transactions: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
                                        .font(.caption)
                                        .foregroundColor(balanceColor(for: account))
                                }
                            }
                            
                            Spacer()
                            
                            if isDirect {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            } else if isIndirect {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.gray.opacity(0.5)) // Gray checkmark for implicit inclusion
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary.opacity(0.3))
                                    .font(.title3)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .disabled(isIndirect) // Prevent selecting if already included
                }
            }
        }
    }
    
    // MARK: - Logic & Helpers
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedMemberIDs.isEmpty
    }
    
    private var availableAccounts: [Account] {
        accountStore.accounts.filter { !$0.isArchived }
            .sorted { $0.name < $1.name }
    }
    
    private var availableGroups: [AccountGroup] {
        accountStore.accountGroups
            .filter { $0.id != groupToEdit?.id } // Cannot add self
            .sorted { $0.name < $1.name }
    }
    
    private var filteredAccounts: [Account] {
        if searchText.isEmpty { return availableAccounts }
        return availableAccounts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredGroups: [AccountGroup] {
        if searchText.isEmpty { return availableGroups }
        return availableGroups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Smart Selection Logic
    
    /// Returns IDs of accounts that are already included inside the GROUPS currently selected.
    /// Used to disable/gray out individual accounts to prevent redundancy.
    private var indirectlySelectedMemberIDs: Set<UUID> {
        var indirectIDs = Set<UUID>()
        
        // 1. Identify which selected IDs are actually Groups
        let selectedGroupIDs = selectedMemberIDs.filter { id in
            accountStore.accountGroups.contains(where: { $0.id == id })
        }
        
        // 2. Harvest all children from those groups
        for groupID in selectedGroupIDs {
            if let group = accountStore.accountGroups.first(where: { $0.id == groupID }) {
                let children = group.allAccountIDs(in: accountStore.accountGroups, accounts: accountStore.accounts)
                indirectIDs.formUnion(children)
            }
        }
        
        return indirectIDs
    }
    
    private func toggleSelection(for id: UUID) {
        if selectedMemberIDs.contains(id) {
            selectedMemberIDs.remove(id)
        } else {
            selectedMemberIDs.insert(id)
        }
    }
    
    private func attemptToggleGroup(_ candidate: AccountGroup) {
        // 1. Deselection is always safe
        if selectedMemberIDs.contains(candidate.id) {
            selectedMemberIDs.remove(candidate.id)
            return
        }
        
        // 2. Cycle Detection
        // Create a temporary version of the group we are building to check for cycles
        let currentGroupID = groupToEdit?.id ?? UUID()
        let tempGroup = AccountGroup(id: currentGroupID, name: name, memberIDs: Array(selectedMemberIDs))
        
        if tempGroup.wouldCreateCycle(byAdding: candidate.id, in: accountStore.accountGroups) {
            cycleAlertMessage = "Adding '\(candidate.name)' would create a circular reference (it already contains this group)."
            showingCycleAlert = true
            return
        }
        
        // 3. Redundancy Cleanup
        // If we add this group, we should remove any individual accounts currently selected
        // that are INSIDE this candidate group, to prevent double-listing.
        let childrenOfCandidate = candidate.allAccountIDs(in: accountStore.accountGroups, accounts: accountStore.accounts)
        
        // Remove direct account selections if they are covered by this new group
        let redundancy = selectedMemberIDs.intersection(childrenOfCandidate)
        if !redundancy.isEmpty {
            selectedMemberIDs.subtract(redundancy)
        }
        
        // 4. Add the group
        selectedMemberIDs.insert(candidate.id)
    }
    
    private func handleSearchSubmit() {
        if searchText.isEmpty {
            if canSave {
                saveGroup()
            }
        } else if filteredAccounts.count + filteredGroups.count == 1 {
            // Auto-select single result
            if let account = filteredAccounts.first {
                if !indirectlySelectedMemberIDs.contains(account.id) {
                    toggleSelection(for: account.id)
                }
            } else if let group = filteredGroups.first {
                attemptToggleGroup(group)
            }
            searchText = ""
        }
    }
    
    private func saveGroup() {
        if var group = groupToEdit {
            group.name = name
            group.memberIDs = Array(selectedMemberIDs)
            accountStore.updateAccountGroup(group)
        } else {
            accountStore.addAccountGroup(name: name, memberIDs: Array(selectedMemberIDs))
        }
        dismiss()
    }
    
    // MARK: - Styling Helpers
    
    private func balanceColor(for account: Account) -> Color {
        let balance = accountStore.balance(for: account, transactions: transactionStore.transactions)
        
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
