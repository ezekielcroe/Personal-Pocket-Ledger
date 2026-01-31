import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    // MARK: - Navigation State
    @State private var showingFilterSheet = false
    @State private var showingReconcileSheet = false
    @State private var showingPresetPicker = false
    
    // MARK: - Analytics State
    @State private var timeRange: TimeRange = .thisMonth
    @State private var breakdownMode: BreakdownMode = .category
    
    // Anchor Date (defaults to today)
    @State private var selectedAnchorDate = Date()

    // MARK: - Filter State
    @State var excludedAccountIDs: Set<UUID> = []
    @State var excludedCategoryIDs: Set<UUID> = []
    @State var excludedTagIDs: Set<UUID> = []
    @State var excludeOutliers: Bool = false
    @State var minimumAmount: Double? = nil
    @State var maximumAmount: Double? = nil
    
    @State private var selectedPresetID: UUID? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. Controls (Date & Filter Banner)
                        VStack(spacing: 12) {
                            // Date Range Picker
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(TimeRange.allCases, id: \.self) { range in
                                        FilterChip(
                                            title: range.rawValue,
                                            isSelected: timeRange == range,
                                            action: { timeRange = range }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Active Filter Banner
                            if !isDefaultState {
                                activeViewBanner
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // 2. Trend Header (Income vs Expense + Comparison)
                        let stats = calculateStats(for: timeRange, offset: 0)
                        let previousStats = calculateStats(for: timeRange, offset: -1)
                        
                        TrendHeaderCard(
                            current: stats,
                            previous: previousStats,
                            rangeName: timeRange.rawValue,
                            currencySymbol: currencySymbol
                        )
                        
                        // 3. Breakdown Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Spending Breakdown")
                                    .font(.headline)
                                Spacer()
                                // Dimension Toggle
                                Picker("Breakdown", selection: $breakdownMode) {
                                    ForEach(BreakdownMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            .padding(.horizontal)
                            
                            if stats.breakdownItems.isEmpty {
                                if #available(iOS 17.0, *) {
                                    ContentUnavailableView(
                                        "No Data",
                                        systemImage: "chart.pie",
                                        description: Text("No spending found for this period/filter.")
                                    )
                                    .padding(.vertical, 40)
                                } else {
                                    Text("No spending found for this period.")
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(stats.breakdownItems) { item in
                                        rowDestination(for: item)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                        
                        // Footer Padding
                        Color.clear.frame(height: 80)
                    }
                }
                
                // FAB Menu
                Menu {
                    Button { showingPresetPicker = true } label: {
                        Label("Saved Views", systemImage: "bookmark")
                    }
                    Button { showingFilterSheet = true } label: {
                        Label("Filter Data", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    Divider()
                    // UPDATED: Reconcile Button
                    Button { showingReconcileSheet = true } label: {
                        Label("Reconcile Accounts", systemImage: "checkmark.seal")
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
                }
                .padding()
                .padding(.bottom, 10)
            }
            .navigationTitle("Insights")
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    excludedAccountIDs: $excludedAccountIDs,
                    excludedCategoryIDs: $excludedCategoryIDs,
                    excludedTagIDs: $excludedTagIDs,
                    excludeOutliers: $excludeOutliers,
                    minimumAmount: $minimumAmount,
                    maximumAmount: $maximumAmount
                )
                .onDisappear { checkIfCustom() }
            }
            .sheet(isPresented: $showingPresetPicker) {
                PresetPickerSheet(
                    selectedPresetID: $selectedPresetID,
                    onSelect: applyPreset,
                    onReset: applyReset
                )
            }
            // UPDATED: Opens the new Selection View
            .sheet(isPresented: $showingReconcileSheet) {
                ReconcileSelectionView()
                    .environmentObject(data)
            }
        }
    }
    
    // MARK: - Navigation Builders
    
    @ViewBuilder
    private func rowDestination(for item: AnalyticsItem) -> some View {
        let currentInterval = timeRange.dateInterval(relativeTo: selectedAnchorDate, fiscalStartDay: fiscalStartDay)
        let totalExpense = calculateStats(for: timeRange, offset: 0).expense
        
        switch breakdownMode {
        case .category:
            if let category = data.categories.first(where: { $0.id == item.id }) {
                NavigationLink(destination: CategoryDetailView(category: category, monthContext: currentInterval.start)) {
                    CategoryBarRow(item: item, total: totalExpense, currencySymbol: currencySymbol)
                }
                .buttonStyle(.plain)
            }
            
        case .account:
            if let account = data.accounts.first(where: { $0.id == item.id }) {
                NavigationLink(destination: AccountDetailView(account: account)) {
                    CategoryBarRow(item: item, total: totalExpense, currencySymbol: currencySymbol)
                }
                .buttonStyle(.plain)
            }
            
        case .group:
            // NEW: Link to Group Details
            if let group = data.accountGroups.first(where: { $0.id == item.id }) {
                NavigationLink(destination: AccountGroupDetailView(group: group)) {
                    CategoryBarRow(item: item, total: totalExpense, currencySymbol: currencySymbol)
                }
                .buttonStyle(.plain)
            } else if item.name == "Ungrouped" {
                // Non-navigable row for ungrouped items
                CategoryBarRow(item: item, total: totalExpense, currencySymbol: currencySymbol)
            }
            
        case .tag:
            if let tag = data.tags.first(where: { $0.id == item.id }) {
                NavigationLink(destination: TagDetailView(tag: tag, dateFilter: currentInterval)) {
                    CategoryBarRow(item: item, total: totalExpense, currencySymbol: currencySymbol)
                }
                .buttonStyle(.plain)
            } else if item.name == "No Tag" {
                CategoryBarRow(item: item, total: totalExpense, currencySymbol: currencySymbol)
            }
        }
    }

    // MARK: - Banner & Helpers
    
    private var isDefaultState: Bool {
        excludedAccountIDs.isEmpty && excludedCategoryIDs.isEmpty && excludedTagIDs.isEmpty &&
        !excludeOutliers && minimumAmount == nil && maximumAmount == nil
    }
    
    private func applyReset() {
        excludedAccountIDs = []; excludedCategoryIDs = []; excludedTagIDs = []
        excludeOutliers = false; minimumAmount = nil; maximumAmount = nil; selectedPresetID = nil
    }

    private func applyPreset(_ preset: InsightPreset) {
        excludedAccountIDs = preset.excludedAccountIDs
        excludedCategoryIDs = preset.excludedCategoryIDs
        excludedTagIDs = preset.excludedTagIDs
        excludeOutliers = preset.excludeOutliers
        selectedPresetID = preset.id
    }
    
    private func checkIfCustom() {
        if let id = selectedPresetID, let preset = data.insightPresets.first(where: { $0.id == id }) {
            if excludedAccountIDs != preset.excludedAccountIDs ||
               excludedCategoryIDs != preset.excludedCategoryIDs ||
               excludeOutliers != preset.excludeOutliers {
                selectedPresetID = nil
            }
        }
    }
    
    private var activeViewBanner: some View {
        HStack {
            Image(systemName: selectedPresetID != nil ? "bookmark.fill" : "line.3.horizontal.decrease.circle.fill")
            Text(selectedPresetID != nil ? (data.insightPresets.first(where: {$0.id == selectedPresetID})?.name ?? "View") : "Custom Filter")
                .fontWeight(.medium)
            Spacer()
            Button("Clear") { applyReset() }
        }
        .font(.caption)
        .padding(10)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - Analytics Engine
    
    struct AnalyticsStats {
        var income: Double
        var expense: Double
        var net: Double { income - expense }
        var breakdownItems: [AnalyticsItem]
    }
    
    struct AnalyticsItem: Identifiable {
        let id: UUID
        let name: String
        let icon: String // Emoji or SF Symbol name
        let amount: Double
        let color: Color? // Optional override
    }
    
    private func calculateStats(for range: TimeRange, offset: Int) -> AnalyticsStats {
        let dateInterval = range.dateInterval(relativeTo: selectedAnchorDate, fiscalStartDay: fiscalStartDay, offset: offset)
        
        // 1. Identify "Transfer" categories to exclude from Income/Expense
        let transferCategoryIDs = Set(data.categories.filter { $0.name == "Transfer" }.map { $0.id })
        
        // 2. Filter Transactions
        let filtered = data.transactions.filter { tx in
            // Time Filter
            if !dateInterval.contains(tx.date) { return false }
            
            // Standard Filters
            if excludeOutliers && tx.isOutlier { return false }
            if excludedAccountIDs.contains(tx.accountID) { return false }
            if excludedCategoryIDs.contains(tx.categoryID) { return false }
            if !tx.tagIDs.isEmpty && !Set(tx.tagIDs).isDisjoint(with: excludedTagIDs) { return false }
            
            // Amount Filter
            if let min = minimumAmount, tx.amount < min { return false }
            if let max = maximumAmount, tx.amount > max { return false }
            
            return true
        }
        
        // 3. Calculate Totals (excluding transfers)
        let income = filtered
            .filter { $0.type == .inflow && !transferCategoryIDs.contains($0.categoryID) }
            .reduce(0) { $0 + $1.amount }
        
        let expense = filtered
            .filter { $0.type == .outflow && !transferCategoryIDs.contains($0.categoryID) }
            .reduce(0) { $0 + $1.amount }
        
        // 4. Generate Breakdown
        let outflows = filtered.filter { $0.type == .outflow && !transferCategoryIDs.contains($0.categoryID) }
        var breakdown: [AnalyticsItem] = []
        
        switch breakdownMode {
        case .category:
            var dict: [UUID: Double] = [:]
            for tx in outflows { dict[tx.categoryID, default: 0] += tx.amount }
            breakdown = dict.compactMap { (id, amount) in
                guard let cat = data.categories.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: cat.name, icon: cat.emoji, amount: amount, color: nil)
            }
            
        case .account:
            var dict: [UUID: Double] = [:]
            for tx in outflows { dict[tx.accountID, default: 0] += tx.amount }
            breakdown = dict.compactMap { (id, amount) in
                guard let acc = data.accounts.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: acc.name, icon: acc.accountType.icon, amount: amount, color: acc.accountType.color)
            }
            
        case .group:
            // NEW: Group Breakdown Logic
            var dict: [UUID: Double] = [:]
            var ungroupedAmount: Double = 0
            
            // Pre-calculate map of AccountID -> TopLevelGroupID
            var accountToGroupMap: [UUID: UUID] = [:]
            
            // Only consider top-level groups (depth == 0)
            let topLevelGroups = data.accountGroups.filter { data.depth(of: $0) == 0 }
            
            for group in topLevelGroups {
                let memberAccountIDs = group.allAccountIDs(in: data.accountGroups, accounts: data.accounts)
                for accID in memberAccountIDs {
                    accountToGroupMap[accID] = group.id
                }
            }
            
            for tx in outflows {
                if let groupID = accountToGroupMap[tx.accountID] {
                    dict[groupID, default: 0] += tx.amount
                } else {
                    ungroupedAmount += tx.amount
                }
            }
            
            breakdown = dict.compactMap { (id, amount) in
                guard let group = data.accountGroups.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: group.name, icon: "folder.fill", amount: amount, color: .purple)
            }
            
            if ungroupedAmount > 0 {
                breakdown.append(AnalyticsItem(id: UUID(), name: "Ungrouped", icon: "building.columns", amount: ungroupedAmount, color: .secondary))
            }
            
        case .tag:
            var dict: [UUID: Double] = [:]
            var untaggedAmount: Double = 0
            
            for tx in outflows {
                if tx.tagIDs.isEmpty {
                    untaggedAmount += tx.amount
                } else {
                    for tagID in tx.tagIDs {
                        dict[tagID, default: 0] += tx.amount
                    }
                }
            }
            breakdown = dict.compactMap { (id, amount) in
                guard let tag = data.tags.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: tag.name, icon: "#", amount: amount, color: .blue)
            }
            if untaggedAmount > 0 {
                breakdown.append(AnalyticsItem(id: UUID(), name: "No Tag", icon: "tag.slash", amount: untaggedAmount, color: .secondary))
            }
        }
        
        return AnalyticsStats(
            income: income,
            expense: expense,
            breakdownItems: breakdown.sorted { $0.amount > $1.amount }
        )
    }
}

// MARK: - Enums & Components

enum TimeRange: String, CaseIterable {
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case last3Months = "Last 3 Months"
    case ytd = "YTD"
    case lastYear = "Last Year"
    case allTime = "All Time"
    
    func dateInterval(relativeTo anchor: Date, fiscalStartDay: Int, offset: Int = 0) -> DateInterval {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: anchor)
        components.day = fiscalStartDay
        
        // Calculate the "Current Month Start" based on fiscal day
        var currentMonthStart = calendar.date(from: components)!
        if anchor < currentMonthStart {
            currentMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
        }
        
        switch self {
        case .thisMonth:
            let start = calendar.date(byAdding: .month, value: offset, to: currentMonthStart)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return DateInterval(start: start, end: end)
            
        case .lastMonth:
            let baseStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
            let start = calendar.date(byAdding: .month, value: offset, to: baseStart)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return DateInterval(start: start, end: end)
            
        case .last3Months:
            let durationMonths = 3
            let shift = offset * durationMonths
            let currentMonthEnd = calendar.date(byAdding: .month, value: 1, to: currentMonthStart)!
            let windowEnd = calendar.date(byAdding: .month, value: shift, to: currentMonthEnd)!
            let windowStart = calendar.date(byAdding: .month, value: -durationMonths, to: windowEnd)!
            return DateInterval(start: windowStart, end: windowEnd)
            
        case .ytd:
            let currentYearStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: anchor), month: 1, day: 1))!
            let yearShift = offset
            let start = calendar.date(byAdding: .year, value: yearShift, to: currentYearStart)!
            let end = calendar.date(byAdding: .year, value: yearShift, to: Date())!
            return DateInterval(start: start, end: end)
            
        case .lastYear:
            let currentYear = calendar.component(.year, from: anchor)
            let targetYear = currentYear - 1 + offset
            let start = calendar.date(from: DateComponents(year: targetYear, month: 1, day: 1))!
            let end = calendar.date(from: DateComponents(year: targetYear + 1, month: 1, day: 1))!
            return DateInterval(start: start, end: end)
            
        case .allTime:
            return DateInterval(start: Date.distantPast, end: Date.distantFuture)
        }
    }
}

// UPDATED: Added Group Case
enum BreakdownMode: String, CaseIterable {
    case category = "Category"
    case group = "Group"
    case account = "Account"
    case tag = "Tag"
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct TrendHeaderCard: View {
    let current: InsightsView.AnalyticsStats
    let previous: InsightsView.AnalyticsStats
    let rangeName: String
    let currencySymbol: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Net Flow Main Stat
            VStack(spacing: 4) {
                Text("Net Cash Flow")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                let net = current.net
                Text("\(net >= 0 ? "+" : "")\(net.formattedCurrency(symbol: currencySymbol))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(net >= 0 ? .primary : .red)
                
                // Comparison Logic
                if previous.net != 0 {
                    let diff = net - previous.net
                    let icon = diff >= 0 ? "arrow.up" : "arrow.down"
                    let color: Color = diff >= 0 ? .green : .red
                    
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                        Text("\(abs(diff).formattedCurrency(symbol: currencySymbol)) vs previous")
                    }
                    .font(.caption)
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Income vs Expense Row
            HStack {
                StatColumn(
                    title: "Income",
                    amount: current.income,
                    prevAmount: previous.income,
                    color: .green,
                    symbol: currencySymbol
                )
                
                Divider()
                
                StatColumn(
                    title: "Expenses",
                    amount: current.expense,
                    prevAmount: previous.expense,
                    color: .red,
                    symbol: currencySymbol
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct StatColumn: View {
    let title: String
    let amount: Double
    let prevAmount: Double
    let color: Color
    let symbol: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(amount.formattedCurrency(symbol: symbol))
                .font(.headline)
                .foregroundColor(color)
            
            // Percentage Change
            if prevAmount > 0 {
                let pct = ((amount - prevAmount) / prevAmount) * 100
                let isUp = pct > 0
                // For Expense: Up is Red (Bad). For Income: Up is Green (Good).
                let indicatorColor: Color = (title == "Expenses" ? (isUp ? .red : .green) : (isUp ? .green : .red))
                
                HStack(spacing: 2) {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    Text("\(String(format: "%.0f", abs(pct)))%")
                }
                .font(.caption2)
                .foregroundColor(indicatorColor)
            } else {
                Text("-")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryBarRow: View {
    let item: InsightsView.AnalyticsItem
    let total: Double
    let currencySymbol: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                // Icon / Emoji
                if item.icon.count == 1 { // Emoji
                    Text(item.icon)
                } else { // SF Symbol
                    Image(systemName: item.icon)
                        .foregroundColor(item.color ?? .primary)
                }
                
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(item.amount.formattedCurrency(symbol: currencySymbol))
                        .font(.subheadline)
                        .monospacedDigit()
                    
                    if total > 0 {
                        Text("\(Int((item.amount / total) * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(item.color ?? .blue)
                        .frame(width: barWidth(totalWidth: geometry.size.width), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func barWidth(totalWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        let ratio = item.amount / total
        return totalWidth * CGFloat(min(max(ratio, 0), 1.0))
    }
}

// MARK: - Preset Picker Sheet

struct PresetPickerSheet: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    @Binding var selectedPresetID: UUID?
    let onSelect: (InsightPreset) -> Void
    let onReset: () -> Void
    
    @State private var presetToEdit: InsightPreset?
    
    var body: some View {
        NavigationStack {
            List {
                // Section 1: Default "All Data" View
                Section {
                    Button {
                        onReset()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(.blue)
                            Text("All Data")
                            Spacer()
                            if selectedPresetID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
                
                // Section 2: User Saved Views
                if !data.insightPresets.isEmpty {
                    Section(header: Text("Saved Views")) {
                        ForEach(data.insightPresets) { preset in
                            Button {
                                onSelect(preset)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundColor(.blue)
                                    Text(preset.name)
                                    Spacer()
                                    if selectedPresetID == preset.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    presetToEdit = preset
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    data.deletePreset(preset)
                                    if selectedPresetID == preset.id {
                                        onReset()
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("No saved views yet. Create one by applying filters and tapping 'Save View'.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Views")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $presetToEdit) { preset in
                EditPresetSheet(preset: preset)
                    .environmentObject(data)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Edit Preset Sheet

struct EditPresetSheet: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    let preset: InsightPreset
    @State private var presetName: String
    @FocusState private var isNameFieldFocused: Bool
    
    init(preset: InsightPreset) {
        self.preset = preset
        _presetName = State(initialValue: preset.name)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("View Name")) {
                    TextField("View Name", text: $presetName)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if canSave {
                                saveChanges()
                            }
                        }
                }
                
                Section(header: Text("Filter Summary"), footer: Text("To change filters, apply the view and modify filters from the main screen.")) {
                    if !preset.excludedAccountIDs.isEmpty {
                        HStack {
                            Text("Excluded Accounts")
                            Spacer()
                            Text("\(preset.excludedAccountIDs.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    if !preset.excludedCategoryIDs.isEmpty {
                        HStack {
                            Text("Excluded Categories")
                            Spacer()
                            Text("\(preset.excludedCategoryIDs.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    if !preset.excludedTagIDs.isEmpty {
                        HStack {
                            Text("Excluded Tags")
                            Spacer()
                            Text("\(preset.excludedTagIDs.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    if preset.excludeOutliers {
                        Text("Excludes outlier transactions")
                            .foregroundColor(.secondary)
                    }
                    
                    if preset.excludedAccountIDs.isEmpty &&
                       preset.excludedCategoryIDs.isEmpty &&
                       preset.excludedTagIDs.isEmpty &&
                       !preset.excludeOutliers {
                        Text("No filters applied")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isNameFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }
    
    private var canSave: Bool {
        !presetName.trimmingCharacters(in: .whitespaces).isEmpty && presetName != preset.name
    }
    
    private func saveChanges() {
        var updatedPreset = preset
        updatedPreset.name = presetName
        data.savePreset(updatedPreset)
        dismiss()
    }
}
