//
//  InsightsView.swift
//  Pocket Ledger
//

import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @StateObject private var viewModel = InsightsViewModel()

    @State private var showingFilterSheet = false
    @State private var showingPresetPicker = false
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 16) {
                        pickerSection

                        if isCustomFilterActive {
                            activeViewBanner
                        }

                        TrendHeaderCard(
                            current: viewModel.stats,
                            previous: viewModel.previousStats,
                            rangeName: viewModel.timeRange.rawValue,
                            currencySymbol: currencySymbol
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            breakdownControls

                            if viewModel.stats.breakdownItems.isEmpty {
                                contentUnavailableView
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.stats.breakdownItems) { item in
                                        rowWithNavigation(for: item)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)

                        Color.clear.frame(height: 80)
                    }
                }

                fabMenu
            }
            .navigationTitle("Insights")
            .onAppear                                    { recalculate() }
            .onChange(of: viewModel.timeRange)           { _, _ in recalculate() }
            .onChange(of: viewModel.breakdownMode)       { _, _ in recalculate() }
            .onChange(of: viewModel.breakdownType)       { _, _ in recalculate() }
            .onChange(of: transactionStore.transactions) { _, _ in recalculate() }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    excludedAccountIDs: $viewModel.excludedAccountIDs,
                    excludedCategoryIDs: $viewModel.excludedCategoryIDs,
                    excludedTagIDs: $viewModel.excludedTagIDs,
                    excludeOutliers: $viewModel.excludeOutliers,
                    minimumAmount: $viewModel.minimumAmount,
                    maximumAmount: $viewModel.maximumAmount
                )
                .environmentObject(accountStore)
                .environmentObject(transactionStore)
                .onDisappear { recalculate() }
            }
            .sheet(isPresented: $showingPresetPicker) {
                PresetPickerSheet(
                    selectedPresetID: $viewModel.selectedPresetID,
                    onSelect: applyPreset,
                    onReset: applyReset
                )
                .environmentObject(transactionStore)
            }
        }
    }

    // MARK: - Navigation Destination Builder

    /// Wraps each breakdown row in the correct NavigationLink.
    /// Pseudo-items like "Ungrouped" and "No Tag" have no real model
    /// to navigate to, so they render as plain non-tappable rows.
    @ViewBuilder
    private func rowWithNavigation(for item: AnalyticsItem) -> some View {
        let row = CategoryBarRow(
            item: item,
            total: viewModel.stats.totalForBreakdown,
            currencySymbol: currencySymbol
        )
        let dateInterval = viewModel.currentDateInterval

        switch viewModel.breakdownMode {
        case .category:
            if let category = transactionStore.categories.first(where: { $0.id == item.id }) {
                NavigationLink(destination: CategoryDetailView(category: category, dateFilter: dateInterval)) { row }
            } else {
                row
            }
        case .tag:
            if let tag = transactionStore.tags.first(where: { $0.id == item.id }) {
                NavigationLink(destination: TagDetailView(tag: tag, dateFilter: dateInterval)) { row }
            } else {
                row
            }
        case .account:
            if let account = accountStore.accounts.first(where: { $0.id == item.id }) {
                NavigationLink(destination: AccountDetailView(account: account)) { row }
            } else {
                row
            }
        case .group:
            if let group = accountStore.accountGroups.first(where: { $0.id == item.id }) {
                NavigationLink(destination: AccountGroupDetailView(group: group)) { row }
            } else {
                row
            }
        }
    }

    // MARK: - Subviews

    var pickerSection: some View {
        Picker("Range", selection: $viewModel.timeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    var breakdownControls: some View {
        VStack(spacing: 12) {
            HStack {
                Text(viewModel.breakdownType == .inflow ? "Income Source" : "Spending Breakdown")
                    .font(.headline)
                Spacer()
            }

            HStack {
                Picker("Type", selection: $viewModel.breakdownType) {
                    Text("Expense").tag(TransactionType.outflow)
                    Text("Income").tag(TransactionType.inflow)
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Spacer()

                Picker("Breakdown", selection: $viewModel.breakdownMode) {
                    ForEach(BreakdownMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
        .padding(.horizontal)
    }

    var fabMenu: some View {
        Menu {
            Button { showingPresetPicker = true } label: {
                Label("Saved Views", systemImage: "bookmark")
            }
            Button { showingFilterSheet = true } label: {
                Label("Filter Data", systemImage: "line.3.horizontal.decrease.circle")
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

    var activeViewBanner: some View {
        HStack {
            Image(systemName: viewModel.selectedPresetID != nil
                  ? "bookmark.fill"
                  : "line.3.horizontal.decrease.circle.fill")
            Text(
                viewModel.selectedPresetID != nil
                ? (transactionStore.insightPresets.first(where: { $0.id == viewModel.selectedPresetID })?.name ?? "View")
                : "Custom Filter"
            )
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

    var contentUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No data found for this period")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Logic Helpers

    private var isCustomFilterActive: Bool {
        !viewModel.excludedAccountIDs.isEmpty ||
        !viewModel.excludedCategoryIDs.isEmpty ||
        !viewModel.excludedTagIDs.isEmpty ||
        viewModel.excludeOutliers ||
        viewModel.minimumAmount != nil
    }

    private func recalculate() {
        viewModel.calculate(accountStore: accountStore, transactionStore: transactionStore)
    }

    private func applyReset() {
        viewModel.excludedAccountIDs = []
        viewModel.excludedCategoryIDs = []
        viewModel.excludedTagIDs = []
        viewModel.excludeOutliers = false
        viewModel.minimumAmount = nil
        viewModel.maximumAmount = nil
        viewModel.selectedPresetID = nil
        recalculate()
    }

    private func applyPreset(_ preset: InsightPreset) {
        viewModel.excludedAccountIDs = preset.excludedAccountIDs
        viewModel.excludedCategoryIDs = preset.excludedCategoryIDs
        viewModel.excludedTagIDs = preset.excludedTagIDs
        viewModel.excludeOutliers = preset.excludeOutliers
        viewModel.selectedPresetID = preset.id
        recalculate()
    }
}

// MARK: - Trend Header Card

struct TrendHeaderCard: View {
    let current: AnalyticsStats
    let previous: AnalyticsStats
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
                StatColumn(title: "Income",   amount: current.income,  prevAmount: previous.income,  color: .green, symbol: currencySymbol)
                Divider()
                StatColumn(title: "Expenses", amount: current.expense, prevAmount: previous.expense, color: .red,   symbol: currencySymbol)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Stat Column

struct StatColumn: View {
    let title: String
    let amount: Decimal
    let prevAmount: Decimal
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
                let indicatorColor: Color = (title == "Expenses"
                    ? (isUp ? .red : .green)
                    : (isUp ? .green : .red))

                HStack(spacing: 2) {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    Text("\(String(format: "%.0f", NSDecimalNumber(decimal: abs(pct)).doubleValue))%")
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

// MARK: - Category Bar Row

struct CategoryBarRow: View {
    let item: AnalyticsItem
    let total: Decimal
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
                        let percentage = (item.amount / total) * 100
                        Text("\(NSDecimalNumber(decimal: percentage).intValue)%")
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
        let ratio = NSDecimalNumber(decimal: item.amount / total).doubleValue
        return totalWidth * CGFloat(min(max(ratio, 0.0), 1.0))
    }
}

// MARK: - Preset Picker Sheet

struct PresetPickerSheet: View {
    @EnvironmentObject var transactionStore: TransactionStore
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
                            Image(systemName: "square.grid.2x2").foregroundColor(.blue)
                            Text("All Data")
                            Spacer()
                            if selectedPresetID == nil {
                                Image(systemName: "checkmark").foregroundColor(.blue).fontWeight(.bold)
                            }
                        }
                    }
                }

                if !transactionStore.insightPresets.isEmpty {
                    Section(header: Text("Saved Views")) {
                        ForEach(transactionStore.insightPresets) { preset in
                            Button {
                                onSelect(preset)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill").foregroundColor(.blue)
                                    Text(preset.name)
                                    Spacer()
                                    if selectedPresetID == preset.id {
                                        Image(systemName: "checkmark").foregroundColor(.blue).fontWeight(.bold)
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
                                    transactionStore.deletePreset(preset)
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
                    .environmentObject(transactionStore)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Edit Preset Sheet

struct EditPresetSheet: View {
    @EnvironmentObject var transactionStore: TransactionStore
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

                Section(
                    header: Text("Filter Summary"),
                    footer: Text("To change filters, apply the view and modify filters from the main screen.")
                ) {
                    if !preset.excludedAccountIDs.isEmpty {
                        HStack {
                            Text("Excluded Accounts")
                            Spacer()
                            Text("\(preset.excludedAccountIDs.count)").foregroundColor(.secondary)
                        }
                    }
                    if !preset.excludedCategoryIDs.isEmpty {
                        HStack {
                            Text("Excluded Categories")
                            Spacer()
                            Text("\(preset.excludedCategoryIDs.count)").foregroundColor(.secondary)
                        }
                    }
                    if !preset.excludedTagIDs.isEmpty {
                        HStack {
                            Text("Excluded Tags")
                            Spacer()
                            Text("\(preset.excludedTagIDs.count)").foregroundColor(.secondary)
                        }
                    }
                    if preset.excludeOutliers {
                        Text("Excludes outlier transactions").foregroundColor(.secondary)
                    }
                    if preset.excludedAccountIDs.isEmpty &&
                       preset.excludedCategoryIDs.isEmpty &&
                       preset.excludedTagIDs.isEmpty &&
                       !preset.excludeOutliers {
                        Text("No filters applied").foregroundColor(.secondary)
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
        transactionStore.savePreset(updatedPreset)
        dismiss()
    }
}
