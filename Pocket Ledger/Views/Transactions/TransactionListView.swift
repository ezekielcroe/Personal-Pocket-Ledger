import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
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
    // 1. CHANGED: This is now the source of truth for the list
    @State private var displayedGroups: [TimeGroup] = []
    @State private var collapsedGroups: Set<TimeGroupID> = []
    
    // MARK: - Archive State
    @AppStorage("showArchivedTransactions") private var showArchivedTransactions: Bool = false
    
    // MARK: - Search State
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Main List
                transactionList
                
                // Floating Add Button (only when not in edit mode and not searching)
                if !isEditMode && !isSearchActive {
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
                            let allCollapsed = collapsedGroups.count == displayedGroups.count
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
                    HStack(spacing: 16) {
                        // Search toggle button
                        Button {
                            withAnimation {
                                isSearchActive.toggle()
                                if isSearchActive {
                                    isSearchFocused = true
                                } else {
                                    searchText = ""
                                    isSearchFocused = false
                                }
                            }
                        } label: {
                            Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                        }
                        
                        editButton
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isEditMode && !selection.isEmpty {
                    multiSelectActionBar
                } else if isSearchActive {
                    searchBar
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
            // MARK: - ASYNC SEARCH TRIGGERS
            // 2. CHANGED: Watch for text changes, debounce, and calculate
            .task(id: searchText) {
                // Debounce: Wait 0.3s if user is typing, unless clearing search
                if !searchText.isEmpty {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
                await updateSearchResults()
            }
            // 3. CHANGED: Watch for data/filter changes (no debounce needed usually)
            .task(id: data.transactions) {
                await updateSearchResults()
            }
            .task(id: showArchivedTransactions) {
                await updateSearchResults()
            }
            .task(id: isSearchActive) {
                // When closing search, ensure list resets immediately
                if !isSearchActive && searchText.isEmpty {
                    await updateSearchResults()
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search tags, categories, accounts, amounts...", text: $searchText)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                
                Button("Cancel") {
                    withAnimation {
                        searchText = ""
                        isSearchActive = false
                        isSearchFocused = false
                    }
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
        }
    }
    
    // MARK: - Main List
    
    @ViewBuilder
    private var transactionList: some View {
        List(selection: $selection) {
            if data.transactions.isEmpty {
                emptyState
            } else if displayedGroups.isEmpty {
                // 4. CHANGED: Simplified empty state logic based on active search
                if isSearchActive && !searchText.isEmpty {
                    noSearchResultsState
                } else if !showArchivedTransactions && visibleTransactionsCount == 0 {
                    archivedOnlyState
                } else {
                    // Fallback (usually implies loading or actual empty state)
                     emptyState
                }
            } else {
                // 5. CHANGED: Iterate over the @State variable, not a computed property
                ForEach(displayedGroups, id: \.id) { group in
                    temporalSection(for: group)
                }
                
                // Pagination: Load Archived Button
                if hasArchivedTransactions && !showArchivedTransactions && !isSearchActive {
                    loadArchivedSection
                }
            }
            
            // Spacer for FAB/action bar/search bar
            Color.clear.frame(height: 100).listRowBackground(Color.clear)
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
    private var noSearchResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No results for \"\(searchText)\"")
                .font(.headline)
            Text("Try searching for tags, categories, accounts, or amounts")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
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
            Text("Tap the menu to show archived transactions")
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
            
            // Net flow + count
            HStack(spacing: 8) {
                // Net flow indicator
                let netFlow = group.netFlow
                if netFlow != 0 {
                    Text(netFlow >= 0 ? "+\(netFlow.formattedCurrency(symbol: currencySymbol))" : netFlow.formattedCurrency(symbol: currencySymbol))
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundColor(netFlow >= 0 ? .green : .red)
                }
                
                // Transaction count
                Text("\(group.transactions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
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
                    data.deleteTransaction(transaction)
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
                data.deleteTransaction(transaction)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Load Archived Section
    
    @ViewBuilder
    private var loadArchivedSection: some View {
        Section {
            Button {
                showArchivedTransactions = true
            } label: {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "archivebox")
                            .font(.title3)
                        Text("Show Archived Transactions")
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
    
    // MARK: - Async Search & Grouping Logic
    
    // 6. CHANGED: This entire block was moved from being computed properties to an async function.
    
    /// Main logic to filter and group transactions off the main thread
    private func updateSearchResults() async {
        // 1. Capture Data Snapshot (Value Types)
        // We capture these here so we can pass them into the background sorting
        // without worrying about MainActor warnings later.
        let allTransactions = data.transactions
        let allTags = data.tags
        let allCategories = data.categories
        let allAccounts = data.accounts
        let currentSearchText = searchText
        let isSearchActive = isSearchActive
        let showArchived = showArchivedTransactions
        let cutoffDate = archiveCutoffDate
        
        // 2. Perform Filtering & Grouping in Background
        let newGroups = await Task.detached(priority: .userInitiated) { () -> [TimeGroup] in
            
            // --- Helper: Search Matcher ---
            func matchesSearch(_ transaction: Transaction, query: String) -> Bool {
                let lowercasedQuery = query.lowercased()
                
                // Tags
                let tagNames = transaction.tagIDs.compactMap { tagID in
                    allTags.first(where: { $0.id == tagID })?.name.lowercased()
                }
                if tagNames.contains(where: { $0.contains(lowercasedQuery) }) { return true }
                
                // Category
                if let category = allCategories.first(where: { $0.id == transaction.categoryID }) {
                    if category.name.lowercased().contains(lowercasedQuery) { return true }
                }
                
                // Account
                if let account = allAccounts.first(where: { $0.id == transaction.accountID }) {
                    if account.name.lowercased().contains(lowercasedQuery) { return true }
                }
                
                // Amount
                let amountString = String(format: "%.2f", transaction.amount)
                if amountString.contains(lowercasedQuery) { return true }
                
                let wholeAmount = String(Int(transaction.amount))
                if wholeAmount == lowercasedQuery || amountString.hasPrefix(lowercasedQuery) { return true }
                
                return false
            }
            
            // --- Step A: Filter ---
            let filtered: [Transaction] = allTransactions.filter { transaction in
                // 1. Archive Check
                let isArchived = transaction.date < cutoffDate
                if !showArchived && isArchived && (!isSearchActive || currentSearchText.isEmpty) {
                    return false
                }
                
                // 2. Search Check
                if isSearchActive && !currentSearchText.isEmpty {
                    return matchesSearch(transaction, query: currentSearchText)
                }
                
                return true
            }
            
            // --- Step B: Sort ---
            let sorted = filtered.sorted { $0.date > $1.date }
            
            // --- Step C: Group ---
            var groups: [TimeGroup] = []
            let calendar = Calendar.current
            let now = Date()
            
            // Define time boundaries
            let startOfToday = calendar.startOfDay(for: now)
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
            let startOfThisWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
            let startOfThisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            
            let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!
            let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonthDate)?.start ?? lastMonthDate
            let endOfLastMonth = calendar.dateInterval(of: .month, for: lastMonthDate)?.end ?? lastMonthDate
            
            let twoMonthsAgoDate = calendar.date(byAdding: .month, value: -2, to: now)!
            let startOfTwoMonthsAgo = calendar.dateInterval(of: .month, for: twoMonthsAgoDate)?.start ?? twoMonthsAgoDate
            let endOfTwoMonthsAgo = calendar.dateInterval(of: .month, for: twoMonthsAgoDate)?.end ?? twoMonthsAgoDate
            
            var futureTransactions: [Transaction] = []
            var todayTransactions: [Transaction] = []
            var yesterdayTransactions: [Transaction] = []
            var thisWeekTransactions: [Transaction] = []
            var thisMonthTransactions: [Transaction] = []
            var lastMonthTransactions: [Transaction] = []
            var twoMonthsAgoTransactions: [Transaction] = []
            var archivedTransactions: [Transaction] = []
            
            for transaction in sorted {
                let txDate = transaction.date
                
                if txDate > now { futureTransactions.append(transaction) }
                else if txDate >= startOfToday { todayTransactions.append(transaction) }
                else if txDate >= startOfYesterday { yesterdayTransactions.append(transaction) }
                else if txDate >= startOfThisWeek { thisWeekTransactions.append(transaction) }
                else if txDate >= startOfThisMonth { thisMonthTransactions.append(transaction) }
                else if txDate >= startOfLastMonth && txDate < endOfLastMonth { lastMonthTransactions.append(transaction) }
                else if txDate >= startOfTwoMonthsAgo && txDate < endOfTwoMonthsAgo { twoMonthsAgoTransactions.append(transaction) }
                else { archivedTransactions.append(transaction) }
            }
            
            if !futureTransactions.isEmpty { await groups.append(TimeGroup(period: .future, transactions: futureTransactions)) }
            if !todayTransactions.isEmpty { await groups.append(TimeGroup(period: .today, transactions: todayTransactions)) }
            if !yesterdayTransactions.isEmpty { await groups.append(TimeGroup(period: .yesterday, transactions: yesterdayTransactions)) }
            if !thisWeekTransactions.isEmpty { await groups.append(TimeGroup(period: .thisWeek, transactions: thisWeekTransactions)) }
            if !thisMonthTransactions.isEmpty { await groups.append(TimeGroup(period: .thisMonth, transactions: thisMonthTransactions)) }
            if !lastMonthTransactions.isEmpty { await groups.append(TimeGroup(period: .lastMonth(lastMonthDate), transactions: lastMonthTransactions)) }
            if !twoMonthsAgoTransactions.isEmpty { await groups.append(TimeGroup(period: .twoMonthsAgo(twoMonthsAgoDate), transactions: twoMonthsAgoTransactions)) }
            
            // Only add archived group if specifically requested OR we are searching
            // (If searching, we want to find old transactions too usually)
            if !archivedTransactions.isEmpty {
                if showArchived || (isSearchActive && !currentSearchText.isEmpty) {
                    await groups.append(TimeGroup(period: .archived, transactions: archivedTransactions))
                }
            }
            
            return groups
        }.value
        
        // 3. Update UI on Main Thread
        withAnimation {
            self.displayedGroups = newGroups
        }
    }
    
    // MARK: - Temporal Grouping Helpers
    
    /// Archive cutoff: 3 months ago
    private var archiveCutoffDate: Date {
        Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date.distantPast
    }
    
    private var hasArchivedTransactions: Bool {
        data.transactions.contains { $0.date < archiveCutoffDate }
    }
    
    /// Helper for Empty State Logic
    private var visibleTransactionsCount: Int {
        let cutoffDate = archiveCutoffDate
        return data.transactions.filter { $0.date >= cutoffDate }.count
    }
    
    // MARK: - Actions
    
    private func toggleAllGroups() {
        let allGroupIDs = Set(displayedGroups.map { $0.id })
        let allCollapsed = collapsedGroups.count == allGroupIDs.count
        
        withAnimation {
            if allCollapsed {
                collapsedGroups.removeAll()
            } else {
                collapsedGroups = allGroupIDs
            }
        }
    }

    private func deleteSelectedTransactions() {
        withAnimation {
            // Include linked transactions in selection
            var idsToDelete = selection
            
            for id in selection {
                if let tx = data.transactions.first(where: { $0.id == id }),
                   let linkedID = tx.linkedTransactionID,
                   let linkedTx = data.transactions.first(where: { $0.id == linkedID }) {
                    idsToDelete.insert(linkedTx.id)
                }
            }
            
            data.transactions.removeAll { transaction in
                idsToDelete.contains(transaction.id)
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
        case thisWeek           // 2 days ago through 7 days ago
        case thisMonth          // Earlier this month (after this week)
        case lastMonth(Date)    // Previous calendar month
        case twoMonthsAgo(Date) // Two calendar months ago
        case archived           // 3+ months old
        
        var displayName: String {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMMM"
            
            switch self {
            case .future:
                return "Upcoming"
            case .today:
                return "Today"
            case .yesterday:
                return "Yesterday"
            case .thisWeek:
                return "This Week"
            case .thisMonth:
                return "This Month"
            case .lastMonth(let date):
                return monthFormatter.string(from: date)
            case .twoMonthsAgo(let date):
                return monthFormatter.string(from: date)
            case .archived:
                return "Archived"
            }
        }
        
        var autoExpand: Bool {
            switch self {
            case .future, .today, .yesterday, .thisWeek:
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
        
        /// Net flow: inflows - outflows (transfers excluded)
        var netFlow: Double {
            var total: Double = 0
            for tx in transactions {
                switch tx.type {
                case .inflow:
                    total += tx.amount
                case .outflow:
                    total -= tx.amount
                case .transfer:
                    // Transfers are net-zero, skip
                    break
                }
            }
            return total
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
            case .thisWeek:
                self.id = TimeGroupID(value: "thisWeek")
            case .thisMonth:
                self.id = TimeGroupID(value: "thisMonth")
            case .lastMonth(let date):
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM"
                self.id = TimeGroupID(value: "lastMonth-\(formatter.string(from: date))")
            case .twoMonthsAgo(let date):
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM"
                self.id = TimeGroupID(value: "twoMonthsAgo-\(formatter.string(from: date))")
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
