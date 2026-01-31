import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var data: AppData
    
    // Binding from ContentView for Shortcut support
    @Binding var globalAddTransactionTrigger: Bool
    
    // MARK: - State
    @State private var transactionToEdit: Transaction?
    
    // Multi-Selection State
    @State private var selection = Set<Transaction.ID>()
    @State private var isEditMode = false
    
    // Batch Tagging State
    @State private var isPresentingBatchTagSheet = false
    @State private var batchTagsToAdd: Set<UUID> = []
    
    // MARK: - Temporal Grouping State
    @State private var loadedMonthsCount: Int = 1 // Start with current month
    @State private var collapsedGroups: Set<TimeGroupID> = []
    
    // MARK: - Archive State
    @AppStorage("showArchivedTransactions") private var showArchivedTransactions: Bool = false
    @AppStorage("archiveOlderThanMonths") private var archiveOlderThanMonths: Int = 3

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
                    Menu {
                        Button {
                            toggleAllGroups()
                        } label: {
                            let allCollapsed = collapsedGroups.count == visibleTimeGroups.count
                            Label(allCollapsed ? "Expand All" : "Collapse All",
                                  systemImage: allCollapsed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        }
                        
                        Divider()
                        
                        Button {
                            showArchivedTransactions.toggle()
                        } label: {
                            Label(showArchivedTransactions ? "Hide Archived" : "Show Archived",
                                  systemImage: showArchivedTransactions ? "eye.slash" : "eye")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
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
            } else if visibleTransactions.isEmpty && !showArchivedTransactions {
                archivedOnlyState
            } else {
                ForEach(visibleTimeGroups, id: \.id) { group in
                    temporalSection(for: group)
                }
                
                // Pagination: Load More Button
                if hasMoreToLoad {
                    loadMoreSection
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
    
    @ViewBuilder
    private var archivedOnlyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("All transactions are archived")
                .font(.headline)
            Text("Tap the filter icon to show archived transactions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Temporal Section
    
    @ViewBuilder
    private func temporalSection(for group: TimeGroup) -> some View {
        let isCollapsed = collapsedGroups.contains(group.id)
        
        DisclosureGroup(
            isExpanded: Binding(
                get: { !isCollapsed },
                set: { isExpanded in
                    if isExpanded {
                        collapsedGroups.remove(group.id)
                    } else {
                        collapsedGroups.insert(group.id)
                    }
                }
            ),
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
    private func sectionHeader(for group: TimeGroup) -> some View {
        HStack {
            HStack(spacing: 6) {
                if group.period == .archived {
                    Image(systemName: "archivebox.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(group.displayName)
                    .font(.headline)
                    .foregroundColor(group.period == .archived ? .secondary : .primary)
            }
            
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
    
    // MARK: - Load More Section
    
    @ViewBuilder
    private var loadMoreSection: some View {
        Section {
            Button {
                loadedMonthsCount += 1
            } label: {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.title3)
                        Text("Load Previous Month")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Toolbar Buttons
    
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
    
    // MARK: - Temporal Grouping Logic
    
    private var visibleTransactions: [Transaction] {
        let cutoffDate = archiveCutoffDate
        
        return data.transactions.filter { transaction in
            if showArchivedTransactions {
                return true
            } else {
                return transaction.date >= cutoffDate
            }
        }
    }
    
    private var archiveCutoffDate: Date {
        Calendar.current.date(byAdding: .month, value: -archiveOlderThanMonths, to: Date()) ?? Date.distantPast
    }
    
    private var visibleTimeGroups: [TimeGroup] {
        let sorted = visibleTransactions.sorted { $0.date > $1.date }
        
        var groups: [TimeGroup] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Define time boundaries
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfLastWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfToday)!
        let paginationCutoff = calendar.date(byAdding: .month, value: -loadedMonthsCount, to: startOfToday)!
        
        // Group transactions by time period
        var futureTransactions: [Transaction] = []
        var todayTransactions: [Transaction] = []
        var yesterdayTransactions: [Transaction] = []
        var lastWeekTransactions: [Transaction] = []
        var lastMonthTransactions: [Transaction] = []
        var archivedTransactions: [Transaction] = []
        var olderTransactionsByMonth: [Date: [Transaction]] = [:]
        
        for transaction in sorted {
            if transaction.date > now {
                futureTransactions.append(transaction)
            } else if transaction.date >= startOfToday {
                todayTransactions.append(transaction)
            } else if transaction.date >= startOfYesterday {
                yesterdayTransactions.append(transaction)
            } else if transaction.date >= startOfLastWeek {
                lastWeekTransactions.append(transaction)
            } else if transaction.date >= startOfLastMonth {
                lastMonthTransactions.append(transaction)
            } else if transaction.date < archiveCutoffDate {
                archivedTransactions.append(transaction)
            } else if transaction.date >= paginationCutoff {
                // Group by month for pagination
                let monthStart = calendar.dateInterval(of: .month, for: transaction.date)?.start ?? transaction.date
                olderTransactionsByMonth[monthStart, default: []].append(transaction)
            }
        }
        
        // Build groups in order
        if !futureTransactions.isEmpty {
            groups.append(TimeGroup(period: .future, transactions: futureTransactions))
        }
        if !todayTransactions.isEmpty {
            groups.append(TimeGroup(period: .today, transactions: todayTransactions))
        }
        if !yesterdayTransactions.isEmpty {
            groups.append(TimeGroup(period: .yesterday, transactions: yesterdayTransactions))
        }
        if !lastWeekTransactions.isEmpty {
            groups.append(TimeGroup(period: .lastWeek, transactions: lastWeekTransactions))
        }
        if !lastMonthTransactions.isEmpty {
            groups.append(TimeGroup(period: .lastMonth, transactions: lastMonthTransactions))
        }
        
        // Add monthly groups in reverse chronological order
        let sortedMonths = olderTransactionsByMonth.keys.sorted(by: >)
        for month in sortedMonths {
            if let transactions = olderTransactionsByMonth[month] {
                groups.append(TimeGroup(period: .month(month), transactions: transactions))
            }
        }
        
        // Add archived group if showing archived
        if showArchivedTransactions && !archivedTransactions.isEmpty {
            groups.append(TimeGroup(period: .archived, transactions: archivedTransactions))
        }
        
        return groups
    }
    
    private var hasMoreToLoad: Bool {
        let paginationCutoff = Calendar.current.date(byAdding: .month, value: -loadedMonthsCount, to: Date())!
        let archiveCutoff = archiveCutoffDate
        
        return data.transactions.contains { transaction in
            transaction.date < paginationCutoff && transaction.date >= archiveCutoff
        }
    }
    
    // MARK: - Actions
    
    private func toggleAllGroups() {
        let allGroupIDs = Set(visibleTimeGroups.map { $0.id })
        let allCollapsed = collapsedGroups.count == allGroupIDs.count
        
        withAnimation {
            if allCollapsed {
                collapsedGroups.removeAll()
            } else {
                collapsedGroups = allGroupIDs
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
    enum TimePeriod: Hashable {
        case future
        case today
        case yesterday
        case lastWeek
        case lastMonth
        case month(Date)
        case archived
        
        var displayName: String {
            switch self {
            case .future:
                return "Upcoming"
            case .today:
                return "Today"
            case .yesterday:
                return "Yesterday"
            case .lastWeek:
                return "Last 7 Days"
            case .lastMonth:
                return "Last 30 Days"
            case .month(let date):
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: date)
            case .archived:
                return "Archived"
            }
        }
        
        var autoExpand: Bool {
            switch self {
            case .future, .today, .yesterday:
                return true
            default:
                return false
            }
        }
    }
    
    struct TimeGroup: Identifiable {
        let id: TimeGroupID
        let period: TimePeriod
        let transactions: [Transaction]
        
        var displayName: String {
            period.displayName
        }
        
        init(period: TimePeriod, transactions: [Transaction]) {
            self.period = period
            self.transactions = transactions
            
            // Generate unique ID based on period
            switch period {
            case .future:
                self.id = TimeGroupID(value: "future")
            case .today:
                self.id = TimeGroupID(value: "today")
            case .yesterday:
                self.id = TimeGroupID(value: "yesterday")
            case .lastWeek:
                self.id = TimeGroupID(value: "lastWeek")
            case .lastMonth:
                self.id = TimeGroupID(value: "lastMonth")
            case .month(let date):
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM"
                self.id = TimeGroupID(value: "month-\(formatter.string(from: date))")
            case .archived:
                self.id = TimeGroupID(value: "archived")
            }
        }
    }
    
    struct TimeGroupID: Hashable {
        let value: String
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
            if !selectedIDs.isEmpty {
                onApply()
            }
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
