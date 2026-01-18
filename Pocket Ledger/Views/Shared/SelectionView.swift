import SwiftUI

// MARK: - Single Selection View

/// A generic searchable list for single selection (Accounts/Categories)
struct SelectionView<T: Identifiable>: View where T: Hashable {
    // NEW: Access data for balances and currency symbol
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    let title: String
    let items: [T]
    @Binding var selectedID: T.ID?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    // MARK: - State
    @FocusState private var isSearchFocused: Bool
    
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
    
    // Helper to check type
    private var isAccountView: Bool {
        T.self == Account.self
    }
    
    // Helpers for Grouping Accounts
    private var debitItems: [T] {
        filteredItems.filter { ($0 as? Account)?.isCredit == false }
    }
    
    private var creditItems: [T] {
        filteredItems.filter { ($0 as? Account)?.isCredit == true }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Search Bar for Focus Control
            searchHeader
            
            List {
                // BRANCH: If selecting Accounts, use Sections
                if isAccountView {
                    if !debitItems.isEmpty {
                        Section(header: Text("Debit Accounts")) {
                            ForEach(debitItems) { item in
                                selectionRow(for: item)
                            }
                        }
                    }
                    
                    if !creditItems.isEmpty {
                        Section(header: Text("Credit Accounts")) {
                            ForEach(creditItems) { item in
                                selectionRow(for: item)
                            }
                        }
                    }
                }
                // BRANCH: Standard list for Categories
                else {
                    ForEach(filteredItems) { item in
                        selectionRow(for: item)
                    }
                }
            }
        }
        .navigationTitle(title)
        .onAppear {
            // Optimization: Small delay to allow sheet animation to finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
    
    // Extracted Row Logic to handle both Accounts (with balance) and Categories
    @ViewBuilder
    private func selectionRow(for item: T) -> some View {
        Button {
            selectAndDismiss(item.id)
        } label: {
            HStack {
                // Name Display
                if let account = item as? Account {
                    Text(account.name)
                } else if let category = item as? Category {
                    HStack {
                        Text(category.emoji)
                        Text(category.name)
                    }
                }
                
                Spacer()
                
                // NEW: Balance Display for Accounts
                if let account = item as? Account {
                    let balance = data.balance(for: account)
                    Text(balance.formattedCurrency(symbol: currencySymbol))
                        .font(.subheadline)
                        .foregroundColor(account.isCredit ? .orange : .secondary) // Orange for Credit
                }
                
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
    
    private var searchHeader: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search", text: $searchText)
                .focused($isSearchFocused)
                .submitLabel(.done)
                .onSubmit {
                    // Logic: If only one item remains, select it on Enter
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
    
    private func selectAndDismiss(_ id: T.ID) {
        selectedID = id
        dismiss()
    }
}

// MARK: - Multiple Selection View

/// A searchable list for multiple selection (Tags) with Keyboard-first creation logic
struct MultiSelectionView: View {
    @EnvironmentObject var data: AppData
    let title: String
    let items: [Tag]
    @Binding var selectedIDs: Set<UUID>
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var filteredItems: [Tag] {
        let list = searchText.isEmpty
            ? items
            : items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
                            Text(item.name)
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
                .onSubmit {
                    handleKeyboardSubmit()
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
    
    private var showCreationRow: Bool {
        !searchText.isEmpty && !items.contains(where: { $0.name.caseInsensitiveCompare(searchText) == .orderedSame })
    }
    
    // MARK: - Logic (REFACTORED)
    
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
        
        data.addTag(name: cleanName) //
        
        if let newTag = data.tags.first(where: { $0.name == cleanName }) {
            selectedIDs.insert(newTag.id)
        }
        
        searchText = ""
        isSearchFocused = true
    }
}
