import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var data: AppData
    
    // Binding from ContentView for Shortcut support
    @Binding var globalAddTransactionTrigger: Bool
    
    // MARK: - State
    @State private var transactionToEdit: Transaction?
    @State private var collapsedDates: Set<Date> = []
    
    // Multi-Selection State
    @State private var selection = Set<Transaction.ID>()
    @State private var isEditMode = false
    
    // Batch Tagging State
    @State private var isPresentingBatchTagSheet = false
    @State private var batchTagsToAdd: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Main List
                transactionList
                
                // Floating Add Button (only when not in edit mode)
                if !isEditMode {
                    floatingAddButton
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    collapseExpandButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    editButton
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isEditMode && !selection.isEmpty {
                    multiSelectActionBar
                }
            }
            // Sheets
            .sheet(isPresented: $globalAddTransactionTrigger) {
                AddTransactionView()
                    .environmentObject(data)
            }
            .sheet(item: $transactionToEdit) { transaction in
                AddTransactionView(editingTransaction: transaction)
                    .environmentObject(data)
            }
            .sheet(isPresented: $isPresentingBatchTagSheet) {
                batchTagSheet
            }
        }
    }
    
    // MARK: - Main List
    
    @ViewBuilder
    private var transactionList: some View {
        List(selection: $selection) {
            if data.transactions.isEmpty {
                emptyState
            } else {
                ForEach(groupedTransactions, id: \.date) { group in
                    transactionSection(for: group)
                }
            }
            
            // Spacer for FAB/action bar
            Color.clear.frame(height: 80).listRowBackground(Color.clear)
        }
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No transactions yet")
                .font(.headline)
            Text("Tap + to add your first transaction")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Transaction Section (Grouped by Date)
    
    @ViewBuilder
    private func transactionSection(for group: TransactionGroup) -> some View {
        DisclosureGroup(
            isExpanded: binding(for: group.date),
            content: {
                ForEach(group.transactions) { transaction in
                    if isEditMode {
                        editModeRow(for: transaction)
                    } else {
                        normalModeRow(for: transaction)
                    }
                }
            },
            label: {
                sectionHeader(for: group)
            }
        )
    }
    
    @ViewBuilder
    private func sectionHeader(for group: TransactionGroup) -> some View {
        HStack {
            Text(formatHeaderDate(group.date))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text("\(group.transactions.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
    }
    
    @ViewBuilder
    private func editModeRow(for transaction: Transaction) -> some View {
        TransactionRow(transaction: transaction)
            .environmentObject(data)
            .tag(transaction.id)
            .swipeActions(edge: .leading) {
                Button {
                    transactionToEdit = transaction
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    deleteTransaction(transaction)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
    
    @ViewBuilder
    private func normalModeRow(for transaction: Transaction) -> some View {
        NavigationLink(destination: TransactionDetailView(transaction: transaction).environmentObject(data)) {
            TransactionRow(transaction: transaction)
                .environmentObject(data)
        }
        .swipeActions(edge: .leading) {
            Button {
                transactionToEdit = transaction
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteTransaction(transaction)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    
    @ViewBuilder
    private var collapseExpandButton: some View {
        if !data.transactions.isEmpty {
            Button {
                toggleAllSections()
            } label: {
                let allDates = Set(groupedTransactions.map { $0.date })
                let allCollapsed = collapsedDates.count == allDates.count && !allDates.isEmpty
                Image(systemName: allCollapsed ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    .font(.subheadline)
            }
        }
    }
    
    private var editButton: some View {
        Button(isEditMode ? "Done" : "Edit") {
            withAnimation {
                isEditMode.toggle()
                if !isEditMode {
                    selection.removeAll()
                }
            }
        }
    }
    
    // MARK: - Multi-Select Action Bar
    
    private var multiSelectActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 20) {
                // Selection count
                Text("\(selection.count) selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Add Tags button
                Button {
                    batchTagsToAdd = []
                    isPresentingBatchTagSheet = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.title3)
                        Text("Add Tags")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.blue)
                
                // Delete button
                Button(role: .destructive) {
                    deleteSelectedTransactions()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title3)
                        Text("Delete")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
    }
    
    // MARK: - Floating Add Button
    
    private var floatingAddButton: some View {
        Button {
            globalAddTransactionTrigger = true
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
        .padding(.bottom, 10)
    }
    
    // MARK: - Batch Tag Sheet
    
    private var batchTagSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BatchTagSelectionContent(
                    selectedIDs: $batchTagsToAdd,
                    onApply: { applyTagsToSelection() }
                )
            }
            .navigationTitle("Add Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresentingBatchTagSheet = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    
                    Button {
                        applyTagsToSelection()
                    } label: {
                        Text("Apply Tags")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(batchTagsToAdd.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(batchTagsToAdd.isEmpty)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Data Helpers
    
    private var groupedTransactions: [TransactionGroup] {
        let grouped = Dictionary(grouping: data.transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        let sortedDates = grouped.keys.sorted(by: >)
        return sortedDates.map { date in
            let transactions = grouped[date] ?? []
            return TransactionGroup(
                date: date,
                transactions: transactions.sorted { $0.date > $1.date }
            )
        }
    }
    
    private func binding(for date: Date) -> Binding<Bool> {
        Binding(
            get: { !collapsedDates.contains(date) },
            set: { isExpanded in
                if isExpanded {
                    collapsedDates.remove(date)
                } else {
                    collapsedDates.insert(date)
                }
            }
        )
    }
    
    private func formatHeaderDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Formatters.sectionHeader.string(from: date)
        }
    }
    
    // MARK: - Actions
    
    private func toggleAllSections() {
        let allDates = Set(groupedTransactions.map { $0.date })
        let allCollapsed = collapsedDates.count == allDates.count
        
        withAnimation {
            if allCollapsed {
                collapsedDates.removeAll()
            } else {
                collapsedDates = allDates
            }
        }
    }

    private func deleteTransaction(_ transaction: Transaction) {
        if let index = data.transactions.firstIndex(where: { $0.id == transaction.id }) {
            data.transactions.remove(at: index)
            data.save()
        }
    }
    
    private func deleteSelectedTransactions() {
        withAnimation {
            data.transactions.removeAll { transaction in
                selection.contains(transaction.id)
            }
            
            data.save()
            selection.removeAll()
            isEditMode = false
        }
    }

    private func applyTagsToSelection() {
        guard !batchTagsToAdd.isEmpty else { return }
        
        for id in selection {
            if let index = data.transactions.firstIndex(where: { $0.id == id }) {
                var transaction = data.transactions[index]
                
                // Merge existing tags with new tags
                let existingTags = Set(transaction.tagIDs)
                let mergedTags = existingTags.union(batchTagsToAdd)
                
                transaction.tagIDs = Array(mergedTags)
                data.transactions[index] = transaction
            }
        }
        
        data.save()
        
        // Reset state
        batchTagsToAdd = []
        isPresentingBatchTagSheet = false
        selection = []
        isEditMode = false
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Supporting Types

extension TransactionListView {
    struct TransactionGroup {
        let date: Date
        let transactions: [Transaction]
    }
}

// MARK: - Batch Tag Selection Content

struct BatchTagSelectionContent: View {
    @EnvironmentObject var data: AppData
    @Binding var selectedIDs: Set<UUID>
    let onApply: () -> Void
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var filteredItems: [Tag] {
        let list = searchText.isEmpty
            ? data.tags
            : data.tags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var showCreationRow: Bool {
        !searchText.isEmpty && !data.tags.contains(where: { $0.name.caseInsensitiveCompare(searchText) == .orderedSame })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Header
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
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .padding()
            
            // Tag List
            List {
                if showCreationRow {
                    Button(action: createAndSelectTag) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
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
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // Spacer for bottom toolbar
                Color.clear.frame(height: 80).listRowBackground(Color.clear)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private func handleKeyboardSubmit() {
        if searchText.isEmpty {
            // Empty search + Enter = Apply (if tags selected)
            if !selectedIDs.isEmpty {
                onApply()
            }
        } else if filteredItems.count == 1 {
            // Single result + Enter = Select it and clear search
            toggleSelection(filteredItems[0])
            searchText = ""
            isSearchFocused = true
        } else if showCreationRow {
            // Create row visible + Enter = Create and select
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
        let cleanName = searchText.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }
        
        data.addTag(name: cleanName)
        
        if let newTag = data.tags.first(where: { $0.name == cleanName }) {
            selectedIDs.insert(newTag.id)
        }
        
        searchText = ""
        isSearchFocused = true
    }
}
