import SwiftUI

struct AddAccountGroupView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    // Optional: If editing, pass the existing group
    var groupToEdit: AccountGroup?
    
    @State private var name: String = ""
    @State private var selectedAccountIDs: Set<UUID> = []
    @State private var searchText: String = ""
    
    // MARK: - Focus State
    enum Field {
        case name
        case search
    }
    @FocusState private var focusedField: Field?
    
    init(groupToEdit: AccountGroup? = nil) {
        self.groupToEdit = groupToEdit
        if let group = groupToEdit {
            _name = State(initialValue: group.name)
            _selectedAccountIDs = State(initialValue: Set(group.accountIDs))
        }
    }
    
    // MARK: - Filter Logic
    var filteredAccounts: [Account] {
        // Show all accounts (Debit & Credit) or just Debit based on preference.
        // Defaulting to all for flexibility, but you can add .filter { !$0.isCredit } if desired.
        let all = data.accounts
        
        if searchText.isEmpty {
            return all
        } else {
            return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Name Section
                Section(header: Text("Group Name")) {
                    TextField("E.g., Liquid Cash, Travel Fund", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next) // Shows "Next" on keyboard
                        .onSubmit {
                            // Requirement 2: Jump to search bar on Enter
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
                            // Context-aware Return Key
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
                
                // MARK: - Account List
                Section {
                    if filteredAccounts.isEmpty {
                        Text("No accounts found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredAccounts) { account in
                            Button {
                                toggleSelection(for: account)
                            } label: {
                                HStack {
                                    Text(account.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedAccountIDs.contains(account.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // Requirement 3: Bottom Save Button using your StandardFormToolbar
            .formToolbar(
                title: groupToEdit == nil ? "New Group" : "Edit Group",
                canSave: canSave,
                onSave: { saveGroup() },
                onCancel: { dismiss() }
            )
            .onAppear {
                // Requirement 1: Focus Name immediately (only if creating new)
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
            // Requirement 2: Empty search bar Enter = "Complete"
            if canSave {
                saveGroup()
            }
        } else if filteredAccounts.count == 1 {
            // Requirement 2: Narrowed to one option = Select it
            if let account = filteredAccounts.first {
                toggleSelection(for: account)
                searchText = "" // Clear search to allow finding the next one or saving
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
}
