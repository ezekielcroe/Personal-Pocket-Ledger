import SwiftUI

/// One inclusion-based filter screen ("what's in the view"). Edits a draft;
/// only Apply or a save commits it, so Cancel always discards.
struct FilterSheet: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"

    /// Committed filters on the Insights page.
    @Binding var filters: InsightFilters
    /// The applied saved view, if any. Cleared when the applied filters no
    /// longer match it.
    @Binding var selectedPresetID: UUID?
    /// Saved with a view, so re-applying it restores the whole page.
    let breakdownMode: BreakdownMode
    let showsSpending: Bool

    @State private var showingSaveSheet = false

    // MARK: - Draft State

    @State private var selectedAccountIDs: Set<UUID> = []
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var draftExcludeOutliers = false
    @State private var minAmountString = ""
    @State private var maxAmountString = ""

    // MARK: - Lists

    /// Archived accounts aren't listed; any exclusion they already have is kept.
    private var activeAccounts: [Account] {
        accountStore.accounts.filter { !$0.isArchived }
    }

    /// The app's own categories (Transfer, Reconciliation Adjustment) aren't
    /// listed: excluding Transfer would silently zero Saved and Debt paid,
    /// and plugs are always left out anyway.
    private var listedCategories: [Category] {
        transactionStore.categories
            .filter { !$0.isSystemCategory && !$0.isArchived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var activeAccountIDs: Set<UUID> { Set(activeAccounts.map { $0.id }) }
    private var listedCategoryIDs: Set<UUID> { Set(listedCategories.map { $0.id }) }

    // MARK: - Resolved Draft

    /// The draft as exclusions — the form Insights and saved views use, so
    /// accounts and categories created later are included automatically.
    private var draft: InsightFilters {
        let keptAccountExclusions = filters.excludedAccountIDs.subtracting(activeAccountIDs)
        let keptCategoryExclusions = filters.excludedCategoryIDs.subtracting(listedCategoryIDs)
        return InsightFilters(
            excludedAccountIDs: activeAccountIDs.subtracting(selectedAccountIDs).union(keptAccountExclusions),
            excludedCategoryIDs: listedCategoryIDs.subtracting(selectedCategoryIDs).union(keptCategoryExclusions),
            excludeOutliers: draftExcludeOutliers,
            minimumAmount: parsedAmount(minAmountString),
            maximumAmount: parsedAmount(maxAmountString)
        )
    }

    private var selectedPreset: InsightPreset? {
        selectedPresetID.flatMap { id in transactionStore.insightPresets.first { $0.id == id } }
    }

    /// The applied saved view differs from the draft, so it can be updated.
    private var canUpdateSelectedPreset: Bool {
        guard let preset = selectedPreset else { return false }
        return preset.filters != draft ||
            preset.breakdownMode != breakdownMode ||
            preset.showsIncome != !showsSpending
    }

    private var draftAsPreset: InsightPreset {
        var preset = InsightPreset(name: "")
        preset.filters = draft
        return preset
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                quickFilters
                amountRangeSection
                accountsSection
                categoriesSection

                if !draft.isEmpty {
                    Section(header: Text("Active Filters")) {
                        PresetFilterSummary(preset: draftAsPreset, currencySymbol: currencySymbol)
                        Button("Clear All Filters", role: .destructive) {
                            resetDraft()
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
                    draft: draftAsPreset,
                    currencySymbol: currencySymbol,
                    onSave: { name in
                        var preset = draftAsPreset
                        preset.name = name
                        preset.breakdownMode = breakdownMode
                        preset.showsIncome = !showsSpending
                        transactionStore.savePreset(preset)
                        filters = draft
                        selectedPresetID = preset.id
                        dismiss()
                    }
                )
            }
            .onAppear(perform: loadDraft)
        }
    }

    // MARK: - Bottom Bar

    private var applyBar: some View {
        VStack(spacing: 8) {
            Divider()

            if let preset = selectedPreset, canUpdateSelectedPreset {
                Button {
                    var updated = preset
                    updated.filters = draft
                    updated.breakdownMode = breakdownMode
                    updated.showsIncome = !showsSpending
                    transactionStore.savePreset(updated)
                    filters = draft
                    dismiss()
                } label: {
                    Label("Update “\(preset.name)”", systemImage: "bookmark.fill")
                        .font(.subheadline.weight(.medium))
                }
            }

            HStack(spacing: 12) {
                if !draft.isEmpty {
                    Button {
                        showingSaveSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "bookmark")
                            Text(selectedPreset == nil ? "Save View" : "Save as New")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                }
                Button {
                    commit()
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
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Sections

    private var quickFilters: some View {
        Section(header: Text("Quick Filters")) {
            QuickFilterButton(icon: "checkmark.circle.fill", title: "All Data",
                              isActive: draft.isEmpty) { resetDraft() }
            QuickFilterButton(icon: "creditcard", title: "Only Debit Accounts",
                              isActive: isDebitOnlyActive) { toggleDebitOnly() }
            QuickFilterButton(icon: "chart.bar", title: "Exclude Outliers",
                              isActive: draftExcludeOutliers) { draftExcludeOutliers.toggle() }
            QuickFilterButton(icon: "dollarsign.circle",
                              title: "Large Only (over \(Self.largeThreshold.formattedCurrency(symbol: currencySymbol)))",
                              isActive: parsedAmount(minAmountString) == Self.largeThreshold) { toggleLarge() }
        }
    }

    private var amountRangeSection: some View {
        Section(header: Text("Amount Range")) {
            HStack {
                Text("Minimum")
                Spacer()
                TextField("No limit", text: $minAmountString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
            }
            HStack {
                Text("Maximum")
                Spacer()
                TextField("No limit", text: $maxAmountString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
            }
        }
    }

    @ViewBuilder
    private var accountsSection: some View {
        if !activeAccounts.isEmpty {
            Section(header: Text("Accounts"),
                    footer: Text("Unticked accounts are left out. Transfers count if neither side is left out.")) {
                ForEach(accountsByType, id: \.type) { section in
                    DisclosureGroup {
                        selectAllRow(ids: Set(section.accounts.map { $0.id }), in: $selectedAccountIDs)
                        ForEach(section.accounts) { account in
                            checkRow(isOn: selectedAccountIDs.contains(account.id)) {
                                toggle(account.id, in: &selectedAccountIDs)
                            } label: {
                                Image(systemName: account.accountType.icon)
                                    .foregroundColor(account.accountType.color)
                                Text(account.name).foregroundColor(.primary)
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
    }

    @ViewBuilder
    private var categoriesSection: some View {
        let spending = listedCategories.filter { $0.type == .outflow }
        let income = listedCategories.filter { $0.type == .inflow }
        if !listedCategories.isEmpty {
            Section(header: Text("Categories")) {
                categoryGroup(title: "Spending", categories: spending)
                categoryGroup(title: "Income", categories: income)
            }
        }
    }

    @ViewBuilder
    private func categoryGroup(title: String, categories: [Category]) -> some View {
        if !categories.isEmpty {
            DisclosureGroup {
                selectAllRow(ids: Set(categories.map { $0.id }), in: $selectedCategoryIDs)
                ForEach(categories) { category in
                    checkRow(isOn: selectedCategoryIDs.contains(category.id)) {
                        toggle(category.id, in: &selectedCategoryIDs)
                    } label: {
                        Text(category.emoji)
                        Text(category.name).foregroundColor(.primary)
                    }
                }
            } label: {
                HStack {
                    Text(title).fontWeight(.medium)
                    Spacer()
                    let n = categories.filter { selectedCategoryIDs.contains($0.id) }.count
                    Text("\(n)/\(categories.count)")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Row Builders

    private func checkRow<RowLabel: View>(isOn: Bool, action: @escaping () -> Void,
                                          @ViewBuilder label: () -> RowLabel) -> some View {
        Button(action: action) {
            HStack {
                label()
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn ? .blue : .secondary.opacity(0.3))
            }
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// "Select all" / "Select none" for one group.
    private func selectAllRow(ids: Set<UUID>, in selection: Binding<Set<UUID>>) -> some View {
        let allSelected = ids.isSubset(of: selection.wrappedValue)
        return Button(allSelected ? "Select None" : "Select All") {
            if allSelected {
                selection.wrappedValue.subtract(ids)
            } else {
                selection.wrappedValue.formUnion(ids)
            }
        }
        .font(.caption)
    }

    // MARK: - Helpers

    private var accountsByType: [(type: AccountType, accounts: [Account])] {
        [AccountType.debit, .goal, .limit, .debt].compactMap { type in
            let list = activeAccounts
                .filter { $0.accountType == type }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return list.isEmpty ? nil : (type, list)
        }
    }

    private func toggle(_ id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    /// Empty text means "no limit". Uses the same parser as amount fields,
    /// so comma-decimal locales work too.
    private func parsedAmount(_ text: String) -> Decimal? {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return MathParser.evaluate(text)
    }

    private func amountString(_ amount: Decimal?) -> String {
        guard let amount else { return "" }
        return NSDecimalNumber(decimal: amount).stringValue
    }

    // MARK: - Draft Lifecycle

    private func loadDraft() {
        selectedAccountIDs   = activeAccountIDs.subtracting(filters.excludedAccountIDs)
        selectedCategoryIDs  = listedCategoryIDs.subtracting(filters.excludedCategoryIDs)
        draftExcludeOutliers = filters.excludeOutliers
        minAmountString      = amountString(filters.minimumAmount)
        maxAmountString      = amountString(filters.maximumAmount)
    }

    /// Applies the draft. If it no longer matches the selected saved view,
    /// the view is deselected so the banner doesn't show a stale name.
    private func commit() {
        let newFilters = draft
        filters = newFilters
        if let preset = selectedPreset, preset.filters != newFilters {
            selectedPresetID = nil
        }
    }

    private func resetDraft() {
        selectedAccountIDs   = activeAccountIDs
        selectedCategoryIDs  = listedCategoryIDs
        draftExcludeOutliers = false
        minAmountString = ""
        maxAmountString = ""
    }

    // MARK: - Quick Filters

    private var debitAccountIDs: Set<UUID> {
        Set(activeAccounts.filter { $0.accountType == .debit }.map { $0.id })
    }

    /// Debit accounts only: Goals are "Future" money, so they're left out.
    private var isDebitOnlyActive: Bool {
        !debitAccountIDs.isEmpty && selectedAccountIDs == debitAccountIDs
    }

    private func toggleDebitOnly() {
        selectedAccountIDs = isDebitOnlyActive ? activeAccountIDs : debitAccountIDs
    }

    private static let largeThreshold: Decimal = 100

    private func toggleLarge() {
        minAmountString = parsedAmount(minAmountString) == Self.largeThreshold ? "" : amountString(Self.largeThreshold)
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
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Save Preset Sheet

struct SavePresetSheet: View {
    @Environment(\.dismiss) var dismiss

    /// The filters being saved (name is ignored).
    let draft: InsightPreset
    let currencySymbol: String
    let onSave: (String) -> Void

    @State private var presetName = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("View Name"),
                        footer: Text("The view also remembers the breakdown and the Spending/Income setting.")) {
                    TextField("E.g., Monthly Spending, Debit Only", text: $presetName)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { if canSave { saveAndDismiss() } }
                }

                Section(header: Text("This View Includes")) {
                    PresetFilterSummary(preset: draft, currencySymbol: currencySymbol)
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
        onSave(presetName.trimmingCharacters(in: .whitespaces))
        dismiss()
    }
}

// MARK: - Preset Filter Summary

/// One line per active filter. Shared by the Save and Edit view sheets.
struct PresetFilterSummary: View {
    let preset: InsightPreset
    let currencySymbol: String

    var body: some View {
        if preset.isEmpty {
            Text("All transactions").foregroundColor(.secondary)
        } else {
            if !preset.excludedAccountIDs.isEmpty {
                Text("Excludes \(preset.excludedAccountIDs.count) account(s)").font(.caption)
            }
            if !preset.excludedCategoryIDs.isEmpty {
                Text("Excludes \(preset.excludedCategoryIDs.count) category(ies)").font(.caption)
            }
            if preset.excludeOutliers {
                Text("Excludes outlier transactions").font(.caption)
            }
            if let min = preset.minimumAmount {
                Text("Minimum \(min.formattedCurrency(symbol: currencySymbol))").font(.caption)
            }
            if let max = preset.maximumAmount {
                Text("Maximum \(max.formattedCurrency(symbol: currencySymbol))").font(.caption)
            }
        }
    }
}
