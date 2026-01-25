import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    // MARK: - State
    @State private var selectedDate = Date()
    @State private var showingFilterSheet = false
    @State private var showingReconcileSheet = false
    @State private var showingPresetPicker = false

    // ACTIVE FILTER STATE
    @State var excludedAccountIDs: Set<UUID> = []
    @State var excludedCategoryIDs: Set<UUID> = []
    @State var excludedTagIDs: Set<UUID> = []
    @State var excludeOutliers: Bool = false
    @State var minimumAmount: Double? = nil
    @State var maximumAmount: Double? = nil
    
    // Current Preset Selection
    @State private var selectedPresetID: UUID? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        // A. Active View Banner (if filtered)
                        if !isDefaultState {
                            activeViewBanner
                        }
                        
                        // B. Date Navigator
                        dateNavigator
                        
                        // C. Stats & Charts
                        CashflowCard(
                            income: monthlyStats.income,
                            expense: monthlyStats.expense,
                            currencySymbol: currencySymbol
                        )

                        VStack(alignment: .leading) {
                            Text("Spending by Category")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if monthlyStats.categoryBreakdown.isEmpty {
                                Text("No spending data for this period.")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(monthlyStats.categoryBreakdown) { item in
                                    if let category = data.categories.first(where: { $0.id == item.id }) {
                                        NavigationLink(destination: CategoryDetailView(category: category, monthContext: selectedDate)) {
                                            CategoryBarRow(
                                                name: item.name,
                                                emoji: item.emoji,
                                                amount: item.amount,
                                                totalContext: monthlyStats.expense,
                                                currencySymbol: currencySymbol
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                        
                        Color.clear.frame(height: 80)
                    }
                }
                
                // Floating Action Menu
                Menu {
                    Button {
                        showingPresetPicker = true
                    } label: {
                        Label("Saved Views", systemImage: "bookmark")
                    }
                    
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Label("Filter Data", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    
                    Divider()
                    
                    Button {
                        showingReconcileSheet = true
                    } label: {
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
            // MARK: - Sheets
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    excludedAccountIDs: $excludedAccountIDs,
                    excludedCategoryIDs: $excludedCategoryIDs,
                    excludedTagIDs: $excludedTagIDs,
                    excludeOutliers: $excludeOutliers,
                    minimumAmount: $minimumAmount,
                    maximumAmount: $maximumAmount
                )
                .onDisappear {
                    checkIfCustom()
                }
            }
            .sheet(isPresented: $showingPresetPicker) {
                PresetPickerSheet(
                    selectedPresetID: $selectedPresetID,
                    onSelect: applyPreset,
                    onReset: applyReset
                )
            }
            .sheet(isPresented: $showingReconcileSheet) {
                ReconcileView()
                    .environmentObject(data)
            }
        }
    }

    // MARK: - Active View Banner
    
    private var activeViewBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: selectedPresetID != nil ? "bookmark.fill" : "line.3.horizontal.decrease.circle.fill")
                    .foregroundColor(.blue)
                
                Text(activeViewName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    applyReset()
                } label: {
                    Text("Clear")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Filter summary
            if !isDefaultState {
                VStack(alignment: .leading, spacing: 4) {
                    if !excludedAccountIDs.isEmpty {
                        Text("Excluding \(excludedAccountIDs.count) account(s)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if !excludedCategoryIDs.isEmpty {
                        Text("Excluding \(excludedCategoryIDs.count) category(ies)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if !excludedTagIDs.isEmpty {
                        Text("Excluding \(excludedTagIDs.count) tag(s)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if excludeOutliers {
                        Text("Excluding outlier transactions")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var activeViewName: String {
        if let id = selectedPresetID,
           let preset = data.insightPresets.first(where: { $0.id == id }) {
            return preset.name
        }
        return "Custom Filter"
    }

    // MARK: - Logic Helpers

    private var isDefaultState: Bool {
        excludedAccountIDs.isEmpty && excludedCategoryIDs.isEmpty && excludedTagIDs.isEmpty &&
        !excludeOutliers && minimumAmount == nil && maximumAmount == nil
    }

    private func applyReset() {
        excludedAccountIDs = []
        excludedCategoryIDs = []
        excludedTagIDs = []
        excludeOutliers = false
        minimumAmount = nil
        maximumAmount = nil
        selectedPresetID = nil
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

    private var dateNavigator: some View {
        VStack(spacing: 4) {
            HStack {
                Button(action: { moveMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthYearString(from: selectedDate))
                    .font(.headline)
                    .frame(minWidth: 150)
                Spacer()
                Button(action: { moveMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
            }
            
            if fiscalStartDay != 1 {
                Text(fiscalRangeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var fiscalRangeString: String {
        let range = getFiscalRange()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }

    private func moveMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Statistics Logic (Transfer Exclusion)

    private var monthlyStats: MonthlyStats {
        let range = getFiscalRange()
        
        // Identify transfer categories to exclude
        let transferCategoryIDs = data.categories
            .filter { $0.name == "Transfer" }
            .map { $0.id }
        
        let filtered = data.transactions.filter { tx in
            if tx.date < range.start || tx.date > range.end { return false }
            if excludeOutliers && tx.isOutlier { return false }
            if excludedAccountIDs.contains(tx.accountID) { return false }
            if excludedCategoryIDs.contains(tx.categoryID) { return false }
            if !tx.tagIDs.isEmpty {
                if !Set(tx.tagIDs).isDisjoint(with: excludedTagIDs) { return false }
            }
            // Exclude transfers from income/expense
            if transferCategoryIDs.contains(tx.categoryID) { return false }
            
            // NEW: Amount filters
            if let min = minimumAmount, tx.amount < min { return false }
            if let max = maximumAmount, tx.amount > max { return false }
            
            return true
        }

        let income = filtered.filter { $0.type == .inflow }.reduce(0) { $0 + $1.amount }
        let expense = filtered.filter { $0.type == .outflow }.reduce(0) { $0 + $1.amount }

        var catDict: [UUID: Double] = [:]
        for tx in filtered where tx.type == .outflow {
            catDict[tx.categoryID, default: 0] += tx.amount
        }

        let breakdown = catDict.compactMap { (id, amount) -> CategoryBreakdownItem? in
            guard let category = data.categories.first(where: { $0.id == id }) else { return nil }
            return CategoryBreakdownItem(id: id, name: category.name, emoji: category.emoji, amount: amount)
        }.sorted { $0.amount > $1.amount }

        return MonthlyStats(income: income, expense: expense, categoryBreakdown: breakdown)
    }
    
    private func getFiscalRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        
        var startComponents = DateComponents()
        startComponents.year = components.year
        startComponents.month = components.month
        startComponents.day = fiscalStartDay
        
        let start = calendar.date(from: startComponents) ?? selectedDate
        let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? selectedDate
        
        return (start, end)
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

// MARK: - Helper Components (Keep existing)

struct MonthlyStats {
    let income: Double
    let expense: Double
    let categoryBreakdown: [CategoryBreakdownItem]
}

struct CategoryBreakdownItem: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let amount: Double
}

struct CashflowCard: View {
    let income: Double
    let expense: Double
    let currencySymbol: String
    
    var net: Double { income - expense }

    var body: some View {
        HStack(spacing: 0) {
            VStack {
                Text("Income")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(income.formattedCurrency(symbol: currencySymbol))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack {
                Text("Expenses")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(expense.formattedCurrency(symbol: currencySymbol))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity)

            Divider()

            VStack {
                Text("Net Flow")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let sign = net >= 0 ? "+" : "-"
                Text("\(sign)\(abs(net).formattedCurrency(symbol: currencySymbol))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(net >= 0 ? .primary : .red)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct CategoryBarRow: View {
    let name: String
    let emoji: String
    let amount: Double
    let totalContext: Double
    let currencySymbol: String

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(emoji)
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(amount.formattedCurrency(symbol: currencySymbol))
                    .font(.subheadline)
                    .monospacedDigit()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: barWidth(totalWidth: geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func barWidth(totalWidth: CGFloat) -> CGFloat {
        guard totalContext > 0 else { return 0 }
        let ratio = amount / totalContext
        return totalWidth * CGFloat(min(max(ratio, 0), 1.0))
    }
}
