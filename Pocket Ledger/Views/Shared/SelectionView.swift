import SwiftUI

// MARK: - Single Selection View

/// A generic searchable list for single selection (Accounts/Categories) with visual enhancements
struct SelectionView<T: Identifiable>: View where T: Hashable {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    let title: String
    let items: [T]
    @Binding var selectedID: T.ID?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    @FocusState private var isSearchFocused: Bool
    
    // NEW: State for collapsed archived section
    @State private var isArchivedExpanded: Bool = false
    
    var filteredItems: [T] {
        let list: [T]
        if searchText.isEmpty {
            list = items
        } else {
            list = items.filter { item in
                if let named = item as? Account {
                    return named.name.localizedCaseInsensitiveContains(searchText)
                }
                if let named = item as? Category {
                    return named.name.localizedCaseInsensitiveContains(searchText)
                }
                return true
            }
        }
        
        return list.sorted { first, second in
            var name1 = ""
            var name2 = ""
            if let a = first as? Account { name1 = a.name }
            else if let c = first as? Category { name1 = c.name }
            if let a = second as? Account { name2 = a.name }
            else if let c = second as? Category { name2 = c.name }
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    private var isAccountView: Bool {
        T.self == Account.self
    }
    
    // MARK: - Account Grouping Logic
    
    // Active accounts grouped by type
    private var activeAccountsByType: [(type: AccountType, accounts: [T])] {
        guard isAccountView else { return [] }
        
        let typeOrder: [AccountType] = [.debit, .goal, .budget, .debt]
        // Filter only Active accounts
        let activeItems = filteredItems.filter { !($0 as? Account)!.isArchived }
        
        return typeOrder.compactMap { type in
            let accountsOfType = activeItems.filter {
                ($0 as? Account)?.accountType == type
            }
            return accountsOfType.isEmpty ? nil : (type, accountsOfType)
        }
    }
    
    // Archived accounts list
    private var archivedAccounts: [T] {
        guard isAccountView else { return [] }
        return filteredItems.filter { ($0 as? Account)!.isArchived }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            
            List {
                if isAccountView {
                    // 1. Active Accounts (Grouped by Type)
                    ForEach(activeAccountsByType, id: \.type) { section in
                        Section(header: sectionHeader(for: section.type)) {
                            ForEach(section.accounts) { item in
                                accountSelectionRow(for: item)
                            }
                        }
                    }
                    
                    // 2. Archived Accounts (Collapsed Section)
                    if !archivedAccounts.isEmpty {
                        DisclosureGroup(isExpanded: $isArchivedExpanded) {
                            ForEach(archivedAccounts) { item in
                                accountSelectionRow(for: item)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "archivebox")
                                Text("Archived Accounts")
                                Spacer()
                                Text("\(archivedAccounts.count)")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                } else {
                    // CATEGORIES: Standard list with emoji
                    ForEach(filteredItems) { item in
                        categorySelectionRow(for: item)
                    }
                }
            }
        }
        .navigationTitle(title)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
    
    // MARK: - Section Header
    
    @ViewBuilder
    private func sectionHeader(for accountType: AccountType) -> some View {
        HStack(spacing: 6) {
            Image(systemName: accountType.icon)
                .foregroundColor(accountType.color)
                .font(.caption)
            Text(accountType.sectionName)
        }
    }
    
    // MARK: - Account Selection Row (Enhanced)
    
    @ViewBuilder
    private func accountSelectionRow(for item: T) -> some View {
        if let account = item as? Account {
            Button {
                selectAndDismiss(item.id)
            } label: {
                HStack(spacing: 12) {
                    // VISUAL: Account Type Icon (Dimmed if archived)
                    AccountTypeIcon(type: account.accountType, size: 32)
                        .opacity(account.isArchived ? 0.5 : 1.0)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(account.name)
                                .foregroundColor(account.isArchived ? .secondary : .primary)
                            
                            // VISUAL: Status Badge (Dimmed if archived)
                            if let badge = account.statusBadge(balance: data.balance(for: account)) {
                                AccountStatusBadgeView(badge: badge)
                                    .opacity(account.isArchived ? 0.5 : 1.0)
                            }
                        }
                        
                        Text(account.accountType.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Balance (Dimmed if archived)
                    Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                        .font(.subheadline)
                        .foregroundColor(balanceColor(for: account))
                        .opacity(account.isArchived ? 0.5 : 1.0)
                    
                    // Checkmark
                    if item.id == selectedID {
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
    
    // MARK: - Category Selection Row (Enhanced)
    
    @ViewBuilder
    private func categorySelectionRow(for item: T) -> some View {
        if let category = item as? Category {
            Button {
                selectAndDismiss(item.id)
            } label: {
                HStack(spacing: 12) {
                    // VISUAL: Category Emoji
                    Text(category.emoji)
                        .font(.title2)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                    
                    Text(category.name)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Checkmark
                    if item.id == selectedID {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .padding(.leading, 8)
                    }
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search", text: $searchText)
                .focused($isSearchFocused)
                .submitLabel(.done)
                .onSubmit {
                    if filteredItems.count == 1 {
                        selectAndDismiss(filteredItems[0].id)
                    }
                }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding()
    }
    
    // MARK: - Helpers
    
    private func selectAndDismiss(_ id: T.ID) {
        selectedID = id
        dismiss()
    }
    
    private func balanceColor(for account: Account) -> Color {
        if account.isArchived { return .secondary }
        
        let balance = data.balance(for: account)
        
        switch account.accountType {
        case .debit:
            return balance < 0 ? .red : .secondary
        case .goal:
            if let target = account.targetAmount, balance >= target {
                return .green
            }
            return .secondary
        case .budget:
            if let target = account.targetAmount, balance > target {
                return .red
            }
            return .secondary
        case .debt:
            return balance > 0 ? .orange : .green
        }
    }
}

// MARK: - Multiple Selection View (Enhanced)

/// A searchable list for multiple selection (Tags) with Keyboard-first creation logic
struct MultiSelectionView: View {
    @EnvironmentObject var data: AppData
    let title: String
    let items: [Tag]
    @Binding var selectedIDs: Set<UUID>
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var filteredItems: [Tag] {
        let list: [Tag]
        if searchText.isEmpty {
            list = items
        } else {
            // Check both name and keywords
            list = items.filter { tag in
                tag.name.localizedCaseInsensitiveContains(searchText) ||
                tag.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            
            List {
                if showCreationRow {
                    Button(action: createAndSelectTag) {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundColor(.green)
                            Text("Create \"\(searchText)\"")
                                .fontWeight(.medium)
                        }
                    }
                }

                ForEach(filteredItems) { item in
                    Button {
                        toggleSelection(item)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .foregroundColor(.primary)
                                
                                // Show why it matched if using a keyword
                                if !searchText.isEmpty,
                                   !item.name.localizedCaseInsensitiveContains(searchText),
                                   let match = item.keywords.first(where: { $0.localizedCaseInsensitiveContains(searchText) }) {
                                    Text("Matches: \"\(match)\"")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if selectedIDs.contains(item.id) {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle(title)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
    
    private var searchHeader: some View {
        HStack {
            Image(systemName: "tag")
                .foregroundColor(.secondary)
            TextField("Find or create tags...", text: $searchText)
                .focused($isSearchFocused)
                .submitLabel(.done)
                .onSubmit { handleKeyboardSubmit() }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding()
    }
    
    private var showCreationRow: Bool {
        !searchText.isEmpty && !items.contains(where: { $0.name.caseInsensitiveCompare(searchText) == .orderedSame })
    }
    
    private func handleKeyboardSubmit() {
        if searchText.isEmpty {
            dismiss()
        } else if filteredItems.count == 1 {
            toggleSelection(filteredItems[0])
            searchText = ""
            isSearchFocused = true
        } else if showCreationRow {
            createAndSelectTag()
        }
    }
    
    private func toggleSelection(_ item: Tag) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }
    
    private func createAndSelectTag() {
        let cleanName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        data.addTag(name: cleanName)
        
        if let newTag = data.tags.first(where: { $0.name == cleanName }) {
            selectedIDs.insert(newTag.id)
        }
        
        searchText = ""
        isSearchFocused = true
    }
}
