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
    
    // Toggle for Income vs Expense Breakdown
    @State private var breakdownType: TransactionType = .outflow
    
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
                            // Breakdown Header & Controls
                            VStack(spacing: 12) {
                                HStack {
                                    Text(breakdownType == .inflow ? "Income Source" : "Spending Breakdown")
                                        .font(.headline)
                                    Spacer()
                                }
                                
                                HStack {
                                    // INCOME / EXPENSE TOGGLE
                                    Picker("Type", selection: $breakdownType) {
                                        Text("Expense").tag(TransactionType.outflow)
                                        Text("Income").tag(TransactionType.inflow)
                                    }
                                    .pickerStyle(.segmented)
                                    .fixedSize()
                                    
                                    Spacer()
                                    
                                    // CATEGORY / GROUP / TAG TOGGLE
                                    Picker("Breakdown", selection: $breakdownMode) {
                                        ForEach(BreakdownMode.allCases, id: \.self) { mode in
                                            Text(mode.rawValue).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                }
                            }
                            .padding(.horizontal)
                            
                            // Chart / List
                            if stats.breakdownItems.isEmpty {
                                if #available(iOS 17.0, *) {
                                    ContentUnavailableView(
                                        "No Data",
                                        systemImage: breakdownType == .inflow ? "tray.and.arrow.down" : "cart",
                                        description: Text("No \(breakdownType.rawValue) found for this period.")
                                    )
                                    .padding(.vertical, 40)
                                } else {
                                    Text("No data found.")
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
        let totalForType = calculateStats(for: timeRange, offset: 0).totalForBreakdown
        
        switch breakdownMode {
        case .category:
            if let category = data.categories.first(where: { $0.id == item.id }) {
                NavigationLink(destination: CategoryDetailView(category: category, dateFilter: currentInterval)) {
                    CategoryBarRow(item: item, total: totalForType, currencySymbol: currencySymbol)
                }
                .buttonStyle(.plain)
            }
            
        case .account:
            if let account = data.accounts.first(where: { $0.id == item.id }) {
                NavigationLink(destination: AccountDetailView(account: account)) {
                    CategoryBarRow(item: item, total: totalForType, currencySymbol: currencySymbol)
                }
                .buttonStyle(.plain)
            }
            
        case .group:
            if let group = data.accountGroups.first(where: { $0.id == item.id }) {
                NavigationLink(destination: AccountGroupDetailView(group: group)) {
                    CategoryBarRow(item: item, total: totalForType, currencySymbol: currencySymbol)
                }
                .buttonStyle(.plain)
            } else if item.name == "Ungrouped" {
                CategoryBarRow(item: item, total: totalForType, currencySymbol: currencySymbol)
            }
            
        case .tag:
            if let tag = data.tags.first(where: { $0.id == item.id }) {
                NavigationLink(destination: TagDetailView(tag: tag, dateFilter: currentInterval)) {
                    CategoryBarRow(item: item, total: totalForType, currencySymbol: currencySymbol)
                }
                .buttonStyle(.plain)
            } else if item.name == "No Tag" {
                CategoryBarRow(item: item, total: totalForType, currencySymbol: currencySymbol)
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
        var totalForBreakdown: Double
    }
    
    struct AnalyticsItem: Identifiable {
        let id: UUID
        let name: String
        let icon: String
        let amount: Double
        let color: Color?
    }
    
    private func calculateStats(for range: TimeRange, offset: Int) -> AnalyticsStats {
        let dateInterval = range.dateInterval(relativeTo: selectedAnchorDate, fiscalStartDay: fiscalStartDay, offset: offset)
        
        // 1. Build lookup sets for smart transfer handling
        let transferCategoryIDs = Set(data.categories.filter { $0.name == "Transfer" }.map { $0.id })
        
        // Only pure DEBT accounts trigger the "transfer = expense" logic
        // Budget accounts (credit cards) record spending as outflows, so their payments are just internal transfers
        let pureDebtAccountIDs = Set(data.accounts.filter { $0.accountType == .debt }.map { $0.id })
        
        // 2. Filter Transactions (basic filters)
        let filtered = data.transactions.filter { tx in
            if !dateInterval.contains(tx.date) { return false }
            if excludeOutliers && tx.isOutlier { return false }
            if excludedAccountIDs.contains(tx.accountID) { return false }
            if excludedCategoryIDs.contains(tx.categoryID) { return false }
            if !tx.tagIDs.isEmpty && !Set(tx.tagIDs).isDisjoint(with: excludedTagIDs) { return false }
            if let min = minimumAmount, tx.amount < min { return false }
            if let max = maximumAmount, tx.amount > max { return false }
            return true
        }
        
        // 3. Calculate Global Totals with SMART TRANSFER HANDLING
        //
        // Account Type Logic:
        // - Debit/Goal: Normal accounts (checking, savings)
        // - Budget: Credit cards - spending recorded as outflows, payments are internal transfers
        // - Debt: Mortgages/loans - can't spend FROM them, transfers TO them ARE expenses
        //
        // Transfer Rules:
        // - Transfer TO a pure Debt account: counts as EXPENSE (paying mortgage/loan)
        // - All other transfers: excluded (internal movement or paying credit card balance)
        
        var income: Double = 0
        var expense: Double = 0
        
        for tx in filtered {
            let isTransferCategory = transferCategoryIDs.contains(tx.categoryID)
            
            if isTransferCategory {
                // Smart transfer logic - only transfers TO pure Debt accounts count as expense
                // We look at the INFLOW side of the transfer to see where money went
                if tx.type == .inflow && pureDebtAccountIDs.contains(tx.accountID) {
                    // Money flowing INTO a Debt account (mortgage payment, loan payment)
                    if let linkedID = tx.linkedTransactionID,
                       let linkedTx = data.transactions.first(where: { $0.id == linkedID }) {
                        if !pureDebtAccountIDs.contains(linkedTx.accountID) {
                            // Money came FROM non-debt TO debt = expense (loan payment)
                            expense += tx.amount
                        }
                    }
                }
                // All other transfer scenarios: exclude from income/expense totals
            } else {
                // Regular transaction (not a transfer)
                if tx.type == .inflow {
                    income += tx.amount
                } else if tx.type == .outflow {
                    expense += tx.amount
                }
            }
        }
        
        // 4. Generate Breakdown
        var breakdownTransactions: [Transaction] = []
        
        for tx in filtered {
            let isTransferCategory = transferCategoryIDs.contains(tx.categoryID)
            
            if breakdownType == .outflow {
                // Include: regular outflows + transfers TO pure Debt accounts
                if tx.type == .outflow && !isTransferCategory {
                    breakdownTransactions.append(tx)
                } else if isTransferCategory && tx.type == .inflow && pureDebtAccountIDs.contains(tx.accountID) {
                    // Payment TO a Debt account
                    if let linkedID = tx.linkedTransactionID,
                       let linkedTx = data.transactions.first(where: { $0.id == linkedID }) {
                        if !pureDebtAccountIDs.contains(linkedTx.accountID) {
                            breakdownTransactions.append(tx)
                        }
                    }
                }
            } else {
                // Income: regular inflows only
                if tx.type == .inflow && !isTransferCategory {
                    breakdownTransactions.append(tx)
                }
            }
        }
        
        let breakdownTotal = breakdownTransactions.reduce(0) { $0 + $1.amount }
        
        var breakdown: [AnalyticsItem] = []
        
        switch breakdownMode {
        case .category:
            var dict: [UUID: Double] = [:]
            for tx in breakdownTransactions { dict[tx.categoryID, default: 0] += tx.amount }
            breakdown = dict.compactMap { (id, amount) in
                guard let cat = data.categories.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: cat.name, icon: cat.emoji, amount: amount, color: nil)
            }
            
        case .account:
            var dict: [UUID: Double] = [:]
            for tx in breakdownTransactions { dict[tx.accountID, default: 0] += tx.amount }
            breakdown = dict.compactMap { (id, amount) in
                guard let acc = data.accounts.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: acc.name, icon: acc.accountType.icon, amount: amount, color: acc.accountType.color)
            }
            
        case .group:
            var dict: [UUID: Double] = [:]
            var ungroupedAmount: Double = 0
            
            var accountToGroupMap: [UUID: UUID] = [:]
            let topLevelGroups = data.accountGroups.filter { data.depth(of: $0) == 0 }
            
            for group in topLevelGroups {
                let memberAccountIDs = group.allAccountIDs(in: data.accountGroups, accounts: data.accounts)
                for accID in memberAccountIDs {
                    accountToGroupMap[accID] = group.id
                }
            }
            
            for tx in breakdownTransactions {
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
            
            for tx in breakdownTransactions {
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
            breakdownItems: breakdown.sorted { $0.amount > $1.amount },
            totalForBreakdown: breakdownTotal
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
        
        var fiscalMonthStart = calendar.date(from: components)!
        if anchor < fiscalMonthStart {
            fiscalMonthStart = calendar.date(byAdding: .month, value: -1, to: fiscalMonthStart)!
        }
        
        switch self {
        case .thisMonth:
            let start = calendar.date(byAdding: .month, value: offset, to: fiscalMonthStart)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return DateInterval(start: start, end: end)
            
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1 + offset, to: fiscalMonthStart)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return DateInterval(start: start, end: end)
            
        case .last3Months:
            let duration = 3
            let currentMonthEnd = calendar.date(byAdding: .month, value: 1, to: fiscalMonthStart)!
            let windowEnd = calendar.date(byAdding: .month, value: offset * duration, to: currentMonthEnd)!
            let windowStart = calendar.date(byAdding: .month, value: -duration, to: windowEnd)!
            return DateInterval(start: windowStart, end: windowEnd)
            
        case .ytd:
            var yearStartComps = calendar.dateComponents([.year], from: fiscalMonthStart)
            yearStartComps.month = 1
            yearStartComps.day = fiscalStartDay
            let fiscalYearStart = calendar.date(from: yearStartComps)!
            
            let start = calendar.date(byAdding: .year, value: offset, to: fiscalYearStart)!
            let end: Date = offset == 0 ? anchor : calendar.date(byAdding: .year, value: offset, to: anchor)!
            return DateInterval(start: start, end: end)
            
        case .lastYear:
            var yearStartComps = calendar.dateComponents([.year], from: fiscalMonthStart)
            yearStartComps.year! -= 1
            yearStartComps.year! += offset
            yearStartComps.month = 1
            yearStartComps.day = fiscalStartDay
            
            let start = calendar.date(from: yearStartComps)!
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
            return DateInterval(start: start, end: end)
            
        case .allTime:
            return DateInterval(start: Date.distantPast, end: Date.distantFuture)
        }
    }
}

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
            VStack(spacing: 4) {
                Text("Net Cash Flow")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                let net = current.net
                Text("\(net >= 0 ? "+" : "")\(net.formattedCurrency(symbol: currencySymbol))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(net >= 0 ? .primary : .red)
                
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
            
            HStack {
                StatColumn(title: "Income", amount: current.income, prevAmount: previous.income, color: .green, symbol: currencySymbol)
                Divider()
                StatColumn(title: "Expenses", amount: current.expense, prevAmount: previous.expense, color: .red, symbol: currencySymbol)
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
            
            if prevAmount > 0 {
                let pct = ((amount - prevAmount) / prevAmount) * 100
                let isUp = pct > 0
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
                if item.icon.count == 1 {
                    Text(item.icon)
                } else {
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
                                Button { presetToEdit = preset } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    data.deletePreset(preset)
                                    if selectedPresetID == preset.id { onReset() }
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
                    Button("Done") { dismiss() }
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
                        .onSubmit { if canSave { saveChanges() } }
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { isNameFieldFocused = true }
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
