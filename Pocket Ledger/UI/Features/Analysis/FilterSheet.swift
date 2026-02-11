import SwiftUI

struct FilterSheet: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss

    @Binding var excludedAccountIDs: Set<UUID>
    @Binding var excludedCategoryIDs: Set<UUID>
    @Binding var excludedTagIDs: Set<UUID>
    @Binding var excludeOutliers: Bool
    @Binding var minimumAmount: Decimal?
    @Binding var maximumAmount: Decimal?

    @State private var showingSaveSheet = false
    @State private var minAmountString = ""
    @State private var maxAmountString = ""

    enum FilterMode { case simple, advanced }
    @State private var filterMode: FilterMode = .simple

    // Simple mode: inclusion-based selections
    @State private var selectedAccountIDs: Set<UUID> = []
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var selectedTagIDs: Set<UUID> = []

    // MARK: - Computed

    private var hasActiveFilters: Bool {
        !excludedAccountIDs.isEmpty || !excludedCategoryIDs.isEmpty ||
        !excludedTagIDs.isEmpty || excludeOutliers ||
        minimumAmount != nil || maximumAmount != nil
    }

    private var filterSummary: String {
        var parts: [String] = []
        if !excludedAccountIDs.isEmpty {
            let included = accountStore.accounts.count - excludedAccountIDs.count
            parts.append("\(included) of \(accountStore.accounts.count) accounts")
        }
        if !excludedCategoryIDs.isEmpty {
            let included = transactionStore.categories.count - excludedCategoryIDs.count
            parts.append("\(included) of \(transactionStore.categories.count) categories")
        }
        if !excludedTagIDs.isEmpty {
            parts.append("Excluding \(excludedTagIDs.count) tags")
        }
        if excludeOutliers { parts.append("Excluding outliers") }
        if let min = minimumAmount { parts.append("Min: \(min.formattedCurrency(symbol: "$"))") }
        if let max = maximumAmount { parts.append("Max: \(max.formattedCurrency(symbol: "$"))") }
        return parts.isEmpty ? "All data included" : parts.joined(separator: " • ")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text(filterMode == .simple ?
                    "Choose what to include in your view" :
                    "Fine-tune by excluding specific items")) {
                    Picker("Filter Mode", selection: $filterMode) {
                        Text("Simple").tag(FilterMode.simple)
                        Text("Advanced").tag(FilterMode.advanced)
                    }
                    .pickerStyle(.segmented)
                }

                if filterMode == .simple {
                    simpleFilterUI
                } else {
                    advancedFilterUI
                }

                if hasActiveFilters {
                    Section(header: Text("Active Filters")) {
                        Text(filterSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Clear All Filters", role: .destructive) {
                            resetFilters()
                        }
                    }
                }

                Color.clear.frame(height: 80).listRowBackground(Color.clear)
            }
            .navigationTitle("Filter Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { applyBar }
            .sheet(isPresented: $showingSaveSheet) {
                SavePresetSheet(
                    excludedAccountIDs: excludedAccountIDs,
                    excludedCategoryIDs: excludedCategoryIDs,
                    excludedTagIDs: excludedTagIDs,
                    excludeOutliers: excludeOutliers,
                    onSave: { name in
                        let preset = InsightPreset(
                            name: name,
                            excludedAccountIDs: excludedAccountIDs,
                            excludedCategoryIDs: excludedCategoryIDs,
                            excludedTagIDs: excludedTagIDs,
                            excludeOutliers: excludeOutliers
                        )
                        transactionStore.savePreset(preset)
                        dismiss()
                    }
                )
            }
            .onAppear {
                initializeSimpleSelections()
                initializeAmountStrings()
            }
        }
    }

    // MARK: - Bottom Bar

    private var applyBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if hasActiveFilters {
                    Button {
                        showingSaveSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "bookmark")
                            Text("Save View")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                }
                Button {
                    if filterMode == .simple { convertSimpleToExclusion() }
                    dismiss()
                } label: {
                    Text("Apply Filters")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Amount Range Section (shared)

    @ViewBuilder
    private func amountRangeSection() -> some View {
        Section(
            header: Text("Amount Range"),
            footer: filterMode == .simple
                ? Text("Filter transactions by amount.")
                : nil
        ) {
            HStack {
                Text("Minimum")
                Spacer()
                TextField("No limit", text: $minAmountString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: minAmountString) { _, new in
                        minimumAmount = Decimal(string: new)
                    }
            }
            HStack {
                Text("Maximum")
                Spacer()
                TextField("No limit", text: $maxAmountString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: maxAmountString) { _, new in
                        maximumAmount = Decimal(string: new)
                    }
            }
        }
    }

    // MARK: - Simple Filter UI

    @ViewBuilder
    private var simpleFilterUI: some View {
        Section(header: Text("Quick Filters")) {
            QuickFilterButton(icon: "checkmark.circle.fill", title: "All Data",
                              isActive: !hasActiveFilters) { resetFilters() }
            QuickFilterButton(icon: "creditcard", title: "Only Debit Accounts",
                              isActive: false) { applyDebitOnlyFilter() }
            QuickFilterButton(icon: "chart.bar", title: "Exclude Outliers",
                              isActive: excludeOutliers) { excludeOutliers.toggle() }
            QuickFilterButton(icon: "dollarsign.circle", title: "Large Expenses Only (>$100)",
                              isActive: minimumAmount == 100) { applyLargeExpensesFilter() }
        }

        amountRangeSection()

        if !accountStore.accounts.isEmpty {
            Section(
                header: Text("Include Accounts"),
                footer: Text("Unselected accounts will be excluded.")
            ) {
                ForEach(accountsByType, id: \.type) { section in
                    DisclosureGroup {
                        ForEach(section.accounts) { account in
                            Button {
                                toggleSelection(account.id, in: &selectedAccountIDs)
                            } label: {
                                HStack {
                                    Image(systemName: account.accountType.icon)
                                        .foregroundColor(accountTypeColor(account.accountType))
                                    Text(account.name).foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: selectedAccountIDs.contains(account.id)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedAccountIDs.contains(account.id)
                                                         ? .blue : .secondary.opacity(0.3))
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(section.type.rawValue).fontWeight(.medium)
                            Spacer()
                            let n = section.accounts.filter { selectedAccountIDs.contains($0.id) }.count
                            Text("\(n)/\(section.accounts.count)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }

        Section(header: Text("Categories (Optional)")) {
            DisclosureGroup("Filter by Categories") {
                Button("Include All") {
                    // FIX: categories live on transactionStore, not accountStore
                    selectedCategoryIDs = Set(transactionStore.categories.map { $0.id })
                }
                .font(.caption)

                ForEach(transactionStore.categories) { category in
                    Button {
                        toggleSelection(category.id, in: &selectedCategoryIDs)
                    } label: {
                        HStack {
                            Text(category.emoji)
                            Text(category.name).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: selectedCategoryIDs.contains(category.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedCategoryIDs.contains(category.id)
                                                 ? .blue : .secondary.opacity(0.3))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Advanced Filter UI

    @ViewBuilder
    private var advancedFilterUI: some View {
        Section(header: Text("General")) {
            Toggle("Exclude Outlier Transactions", isOn: $excludeOutliers)
        }

        amountRangeSection()

        Section(header: Text("Exclude Accounts")) {
            if excludedAccountIDs.isEmpty {
                Text("All accounts included").foregroundColor(.secondary).font(.caption)
            }
            ForEach(accountStore.accounts) { account in
                Button { toggleSelection(account.id, in: &excludedAccountIDs) } label: {
                    HStack {
                        Image(systemName: account.accountType.icon)
                            .foregroundColor(accountTypeColor(account.accountType))
                        Text(account.name).foregroundColor(.primary)
                        Spacer()
                        if excludedAccountIDs.contains(account.id) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        }
                    }
                }
            }
        }

        Section(header: Text("Exclude Categories")) {
            if excludedCategoryIDs.isEmpty {
                Text("All categories included").foregroundColor(.secondary).font(.caption)
            }
            ForEach(transactionStore.categories) { category in
                Button { toggleSelection(category.id, in: &excludedCategoryIDs) } label: {
                    HStack {
                        Text(category.emoji)
                        Text(category.name).foregroundColor(.primary)
                        Spacer()
                        if excludedCategoryIDs.contains(category.id) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        }
                    }
                }
            }
        }

        if !transactionStore.tags.isEmpty {
            Section(header: Text("Exclude Tags")) {
                if excludedTagIDs.isEmpty {
                    Text("All tags included").foregroundColor(.secondary).font(.caption)
                }
                ForEach(transactionStore.tags) { tag in
                    Button { toggleSelection(tag.id, in: &excludedTagIDs) } label: {
                        HStack {
                            Text(tag.name).foregroundColor(.primary)
                            Spacer()
                            if excludedTagIDs.contains(tag.id) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var accountsByType: [(type: AccountType, accounts: [Account])] {
        [AccountType.debit, .goal, .limit, .debt].compactMap { type in
            let list = accountStore.accounts
                .filter { $0.accountType == type }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return list.isEmpty ? nil : (type, list)
        }
    }

    private func accountTypeColor(_ type: AccountType) -> Color {
        switch type {
        case .debit:  return .primary
        case .goal:   return .blue
        case .limit: return .purple
        case .debt:   return .orange
        }
    }

    private func toggleSelection(_ id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func initializeSimpleSelections() {
        selectedAccountIDs  = Set(accountStore.accounts.map { $0.id }).subtracting(excludedAccountIDs)
        selectedCategoryIDs = Set(transactionStore.categories.map { $0.id }).subtracting(excludedCategoryIDs)
        selectedTagIDs      = Set(transactionStore.tags.map { $0.id }).subtracting(excludedTagIDs)
    }

    private func convertSimpleToExclusion() {
        excludedAccountIDs  = Set(accountStore.accounts.map { $0.id }).subtracting(selectedAccountIDs)
        excludedCategoryIDs = Set(transactionStore.categories.map { $0.id }).subtracting(selectedCategoryIDs)
        excludedTagIDs      = Set(transactionStore.tags.map { $0.id }).subtracting(selectedTagIDs)
    }

    private func resetFilters() {
        excludedAccountIDs.removeAll()
        excludedCategoryIDs.removeAll()
        excludedTagIDs.removeAll()
        excludeOutliers = false
        minimumAmount = nil
        maximumAmount = nil
        minAmountString = ""
        maxAmountString = ""
        initializeSimpleSelections()
    }

    private func applyDebitOnlyFilter() {
        selectedAccountIDs = Set(accountStore.accounts.filter { !$0.isCredit }.map { $0.id })
    }

    private func applyLargeExpensesFilter() {
        if minimumAmount == 100 {
            minimumAmount = nil
            minAmountString = ""
        } else {
            minimumAmount = 100
            minAmountString = "100"
        }
    }

    private func initializeAmountStrings() {
        if let min = minimumAmount {
            minAmountString = String(format: "%.2f", (min as NSDecimalNumber).doubleValue)
        }
        if let max = maximumAmount {
            maxAmountString = String(format: "%.2f", (max as NSDecimalNumber).doubleValue)
        }
    }
}

// MARK: - Quick Filter Button

struct QuickFilterButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isActive ? .blue : .secondary)
                Text(title).foregroundColor(.primary)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Save Preset Sheet

struct SavePresetSheet: View {
    @Environment(\.dismiss) var dismiss

    let excludedAccountIDs: Set<UUID>
    let excludedCategoryIDs: Set<UUID>
    let excludedTagIDs: Set<UUID>
    let excludeOutliers: Bool
    let onSave: (String) -> Void

    @State private var presetName = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("View Name")) {
                    TextField("E.g., Monthly Spending, Debit Only", text: $presetName)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { if canSave { saveAndDismiss() } }
                }

                Section(header: Text("This View Includes")) {
                    if excludedAccountIDs.isEmpty && excludedCategoryIDs.isEmpty &&
                       excludedTagIDs.isEmpty && !excludeOutliers {
                        Text("All transactions").foregroundColor(.secondary)
                    } else {
                        if !excludedAccountIDs.isEmpty {
                            Text("Excludes \(excludedAccountIDs.count) account(s)").font(.caption)
                        }
                        if !excludedCategoryIDs.isEmpty {
                            Text("Excludes \(excludedCategoryIDs.count) category(ies)").font(.caption)
                        }
                        if !excludedTagIDs.isEmpty {
                            Text("Excludes \(excludedTagIDs.count) tag(s)").font(.caption)
                        }
                        if excludeOutliers {
                            Text("Excludes outlier transactions").font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Save View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { isNameFieldFocused = true }
        }
        .presentationDetents([.medium])
    }

    private var canSave: Bool {
        !presetName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveAndDismiss() {
        onSave(presetName)
        dismiss()
    }
}
