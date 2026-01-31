import SwiftUI

struct AddAccountGroupView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    // Optional: If editing, pass the existing group
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
                    TextField("E.g., Net Worth, Liquid Cash", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .search
                        }
                }
                
                // MARK: - Display Mode Filter
                Section {
                    Picker("Show", selection: $displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // MARK: - Search Section
                Section(header: Text("Add Members")) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Filter accounts and groups...", text: $searchText)
                            .focused($focusedField, equals: .search)
                            .submitLabel(searchText.isEmpty ? .done : (filteredMembers.count == 1 ? .join : .search))
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
                
                // MARK: - Available Accounts
                if shouldShowAccounts && !filteredAccounts.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "building.columns")
                            .foregroundColor(.blue)
                        Text("Accounts")
                    }) {
                        ForEach(accountsByType, id: \.type) { section in
                            accountTypeSection(section)
                        }
                    }
                }
                
                // MARK: - Available Groups
                if shouldShowGroups && !availableGroups.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.purple)
                        Text("Groups")
                    }, footer: Text("Groups can contain other groups for hierarchical organization")) {
                        ForEach(availableGroups) { group in
                            groupRow(for: group)
                        }
                    }
                }
                
                // MARK: - Empty State
                if filteredMembers.isEmpty {
                    Section {
                        Text("No members found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                
                // MARK: - Current Members Preview
                if !selectedMemberIDs.isEmpty {
                    Section(header: Text("Selected Members (\(selectedMemberIDs.count))")) {
                        ForEach(selectedMembers, id: \.id) { member in
                            memberPreviewRow(member)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveGroup() }
                        .disabled(!canSave)
                }
            }
            .navigationTitle(groupToEdit == nil ? "New Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if groupToEdit == nil {
                    focusedField = .name
                }
            }
            .alert("Cannot Add Group", isPresented: $showingCycleAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(cycleAlertMessage)
            }
        }
    }
    
    // MARK: - Account Type Section
    
    @ViewBuilder
    private func accountTypeSection(_ section: (type: AccountType, accounts: [Account])) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { true },  // Always expanded for easier selection
                set: { _ in }
            )
        ) {
            ForEach(section.accounts) { account in
                accountRow(for: account)
            }
        } label: {
            HStack {
                Image(systemName: section.type.icon)
                    .foregroundColor(section.type.color)
                    .font(.caption)
                Text(section.type.sectionName)
                    .font(.subheadline)
                Spacer()
                Text("\(section.accounts.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Account Row
    
    @ViewBuilder
    private func accountRow(for account: Account) -> some View {
        Button {
            toggleSelection(for: account.id)
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
                
                if selectedMemberIDs.contains(account.id) {
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
    
    // MARK: - Group Row
    
    @ViewBuilder
    private func groupRow(for group: AccountGroup) -> some View {
        // Calculate depth here to avoid scope error
        let depth = data.depth(of: group)
        
        Button {
            attemptToggleGroup(group)
        } label: {
            HStack(spacing: 12) {
                // Group icon with nesting indicator
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                    
                    // Show depth indicator if nested
                    if depth > 0 {
                        Text("\(depth)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(2)
                            .background(Color.purple)
                            .clipShape(Circle())
                            .offset(x: 4, y: 4)
                    }
                }
                .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text("\(group.memberIDs.count) members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if depth > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Depth: \(depth)")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                Spacer()
                
                // FIXED: Use groupBalance(group) instead of balance(for: group)
                Text(data.groupBalance(group).formattedCurrency(symbol: currencySymbol))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                if selectedMemberIDs.contains(group.id) {
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
    
    // MARK: - Member Preview Row
    
    @ViewBuilder
    private func memberPreviewRow(_ member: MemberType) -> some View {
        HStack {
            switch member {
            case .account(let account):
                Image(systemName: account.accountType.icon)
                    .foregroundColor(account.accountType.color)
                Text(account.name)
                
            case .group(let group):
                Image(systemName: "folder.fill")
                    .foregroundColor(.purple)
                Text(group.name)
                
                let depth = data.depth(of: group)
                if depth > 0 {
                    Text("(Depth: \(depth))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                selectedMemberIDs.remove(member.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Filter Logic
    
    private var shouldShowAccounts: Bool {
        displayMode == .all || displayMode == .accounts
    }
    
    private var shouldShowGroups: Bool {
        displayMode == .all || displayMode == .groups
    }
    
    private var filteredAccounts: [Account] {
        guard shouldShowAccounts else { return [] }
        
        let all = data.accounts.filter { !$0.isArchived }
        
        let filtered = searchText.isEmpty ? all : all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        
        return filtered.sorted { lhs, rhs in
            let typeOrder: [AccountType] = [.debit, .goal, .budget, .debt]
            let lhsIndex = typeOrder.firstIndex(of: lhs.accountType) ?? 999
            let rhsIndex = typeOrder.firstIndex(of: rhs.accountType) ?? 999
            
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    private var availableGroups: [AccountGroup] {
        guard shouldShowGroups else { return [] }
        
        // Filter out the group being edited (can't add to itself)
        let filtered = data.accountGroups.filter { group in
            // Exclude self
            if let editingGroup = groupToEdit, group.id == editingGroup.id {
                return false
            }
            
            // Apply search filter
            if !searchText.isEmpty && !group.name.localizedCaseInsensitiveContains(searchText) {
                return false
            }
            
            return true
        }
        
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var filteredMembers: [Any] {
        var result: [Any] = []
        result.append(contentsOf: filteredAccounts)
        result.append(contentsOf: availableGroups)
        return result
    }
    
    private var accountsByType: [(type: AccountType, accounts: [Account])] {
        let typeOrder: [AccountType] = [.debit, .goal, .budget, .debt]
        
        return typeOrder.compactMap { type in
            let accountsOfType = filteredAccounts.filter { $0.accountType == type }
            return accountsOfType.isEmpty ? nil : (type, accountsOfType)
        }
    }
    
    private var selectedMembers: [MemberType] {
        var result: [MemberType] = []
        
        for id in selectedMemberIDs {
            if let account = data.accounts.first(where: { $0.id == id }) {
                result.append(.account(account))
            } else if let group = data.accountGroups.first(where: { $0.id == id }) {
                result.append(.group(group))
            }
        }
        
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Helpers
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedMemberIDs.isEmpty
    }
    
    private func toggleSelection(for id: UUID) {
        if selectedMemberIDs.contains(id) {
            selectedMemberIDs.remove(id)
        } else {
            selectedMemberIDs.insert(id)
        }
    }
    
    private func attemptToggleGroup(_ group: AccountGroup) {
        // Create a temporary group to test for cycles
        let tempGroup = groupToEdit ?? AccountGroup(name: name)
        
        if selectedMemberIDs.contains(group.id) {
            // Removing is always safe
            selectedMemberIDs.remove(group.id)
        } else {
            // Adding requires cycle check
            if tempGroup.wouldCreateCycle(byAdding: group.id, in: data.accountGroups) {
                cycleAlertMessage = "Adding '\(group.name)' would create a circular reference. A group cannot contain itself directly or indirectly."
                showingCycleAlert = true
            } else {
                selectedMemberIDs.insert(group.id)
            }
        }
    }
    
    private func handleSearchSubmit() {
        if searchText.isEmpty {
            if canSave {
                saveGroup()
            }
        } else if filteredMembers.count == 1 {
            if let account = filteredAccounts.first {
                toggleSelection(for: account.id)
            } else if let group = availableGroups.first {
                attemptToggleGroup(group)
            }
            searchText = ""
        }
    }
    
    private func saveGroup() {
        if var group = groupToEdit {
            group.name = name
            group.memberIDs = Array(selectedMemberIDs)
            data.updateAccountGroup(group)
        } else {
            data.addAccountGroup(name: name, memberIDs: Array(selectedMemberIDs))
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
