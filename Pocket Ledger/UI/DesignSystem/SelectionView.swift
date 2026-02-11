import SwiftUI

// MARK: - Single Selection View

struct SelectionView<T: Identifiable>: View where T: Hashable {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    let title: String
    let items: [T]
    @Binding var selectedID: T.ID?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    @FocusState private var isSearchFocused: Bool
    @State private var isArchivedExpanded: Bool = false
    
    var filteredItems: [T] {
        // 1. Filter out archived items immediately for selection purposes
        let activeItems = items.filter { item in
            if let cat = item as? Category {
                return !cat.isArchived
            }
            // Accounts are usually pre-filtered by the caller, but this is a safety check
            if let acc = item as? Account {
                return !acc.isArchived
            }
            return true
        }
        
        let list: [T]
        if searchText.isEmpty {
            list = activeItems
        } else {
            list = activeItems.filter { item in
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
    // (Used only if T is Account)
    
    private var activeAccountsByType: [(type: AccountType, accounts: [T])] {
        guard isAccountView else { return [] }
        
        let typeOrder: [AccountType] = [.debit, .goal, .limit, .debt]
        // Note: filteredItems is already filtered for isArchived above
        
        return typeOrder.compactMap { type in
            let accountsOfType = filteredItems.filter {
                ($0 as? Account)?.accountType == type
            }
            return accountsOfType.isEmpty ? nil : (type, accountsOfType)
        }
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
                    // Note: Archived accounts are hidden in selection view
                    
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
    
    // MARK: - Account Selection Row
    
    @ViewBuilder
    private func accountSelectionRow(for item: T) -> some View {
        if let account = item as? Account {
            Button {
                selectAndDismiss(item.id)
            } label: {
                HStack(spacing: 12) {
                    AccountTypeIcon(type: account.accountType, size: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(account.name)
                                .foregroundColor(.primary)
                            if let badge = account.statusBadge(balance: FinancialCalculator.balance(for: account, in: transactionStore.transactions)) {
                                AccountStatusBadgeView(badge: badge)
                            }
                        }
                        Text(account.accountType.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(FinancialCalculator.balance(for: account, in: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
                        .font(.subheadline)
                        .foregroundColor(balanceColor(for: account))
                    
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
    
    // MARK: - Category Selection Row
    
    @ViewBuilder
    private func categorySelectionRow(for item: T) -> some View {
        if let category = item as? Category {
            Button {
                selectAndDismiss(item.id)
            } label: {
                HStack(spacing: 12) {
                    Text(category.emoji)
                        .font(.title2)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                    
                    Text(category.name)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
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
        let balance = FinancialCalculator.balance(for: account, in: transactionStore.transactions)
        switch account.accountType {
        case .debit: return balance < 0 ? .red : .secondary
        case .goal:
            if let target = account.targetAmount, balance >= target { return .green }
            return .secondary
        case .limit:
            if let target = account.targetAmount, balance > target { return .red }
            return .secondary
        case .debt: return balance > 0 ? .orange : .green
        }
    }
}

// MARK: - Multiple Selection View

/// A searchable list for multiple selection (Tags) with Keyboard-first creation logic
struct MultiSelectionView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    let title: String
    let items: [Tag]
    @Binding var selectedIDs: Set<UUID>
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var filteredItems: [Tag] {
        // 1. Filter out archived tags
        let activeTags = items.filter { !$0.isArchived }
        
        let list: [Tag]
        if searchText.isEmpty {
            list = activeTags
        } else {
            // Check both name and keywords
            list = activeTags.filter { tag in
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
        
        transactionStore.addTag(name: cleanName)
        
        if let newTag = transactionStore.tags.first(where: { $0.name == cleanName }) {
            selectedIDs.insert(newTag.id)
        }
        
        searchText = ""
        isSearchFocused = true
    }
}
