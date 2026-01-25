import SwiftUI

struct FilterSheet: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss

    @Binding var excludedAccountIDs: Set<UUID>
    @Binding var excludedCategoryIDs: Set<UUID>
    @Binding var excludedTagIDs: Set<UUID>
    @Binding var excludeOutliers: Bool
    
    // NEW: Amount filter bindings
    @Binding var minimumAmount: Double?
    @Binding var maximumAmount: Double?
    
    // State for saving preset
    @State private var showingSaveSheet = false
    @State private var newPresetName = ""
    
    // Amount filter UI state
    @State private var minAmountString = ""
    @State private var maxAmountString = ""
    
    // Filter mode
    enum FilterMode {
        case simple
        case advanced
    }
    @State private var filterMode: FilterMode = .simple
    
    // Simple mode selections (inclusion-based)
    @State private var selectedAccountIDs: Set<UUID> = []
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var selectedTagIDs: Set<UUID> = []
    
    // Computed properties
    private var hasActiveFilters: Bool {
        !excludedAccountIDs.isEmpty || !excludedCategoryIDs.isEmpty || !excludedTagIDs.isEmpty ||
        excludeOutliers || minimumAmount != nil || maximumAmount != nil
    }
    
    private var filterSummary: String {
        var parts: [String] = []
        
        let includedAccounts = data.accounts.count - excludedAccountIDs.count
        if excludedAccountIDs.count > 0 {
            parts.append("\(includedAccounts) of \(data.accounts.count) accounts")
        }
        
        let includedCategories = data.categories.count - excludedCategoryIDs.count
        if excludedCategoryIDs.count > 0 {
            parts.append("\(includedCategories) of \(data.categories.count) categories")
        }
        
        if !excludedTagIDs.isEmpty {
            parts.append("Excluding \(excludedTagIDs.count) tags")
        }
        
        if excludeOutliers {
            parts.append("Excluding outliers")
        }
        
        if let min = minimumAmount {
            parts.append("Min: \(min.formattedCurrency(symbol: "$"))")
        }
        
        if let max = maximumAmount {
            parts.append("Max: \(max.formattedCurrency(symbol: "$"))")
        }
        
        return parts.isEmpty ? "All data included" : parts.joined(separator: " • ")
    }

    var body: some View {
        NavigationStack {
            List {
                // Mode Picker
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
                
                // Summary Section
                if hasActiveFilters {
                    Section(header: Text("Active Filters")) {
                        Text(filterSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Clear All Filters") {
                            resetFilters()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // Spacer for bottom toolbar
                Color.clear.frame(height: 80).listRowBackground(Color.clear)
            }
            .navigationTitle("Filter Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        // Save as View button (secondary)
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
                        
                        // Apply button (primary)
                        Button {
                            if filterMode == .simple {
                                convertSimpleToExclusion()
                            }
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
                        data.savePreset(preset)
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
    
    // MARK: - Simple Filter UI
    
    @ViewBuilder
    private var simpleFilterUI: some View {
        // Quick Filters
        Section(header: Text("Quick Filters")) {
            QuickFilterButton(
                icon: "checkmark.circle.fill",
                title: "All Data",
                isActive: !hasActiveFilters
            ) {
                resetFilters()
            }
            
            QuickFilterButton(
                icon: "creditcard",
                title: "Only Debit Accounts",
                isActive: false
            ) {
                applyDebitOnlyFilter()
            }
            
            QuickFilterButton(
                icon: "chart.bar",
                title: "Exclude Outliers",
                isActive: excludeOutliers
            ) {
                excludeOutliers.toggle()
            }
            
            QuickFilterButton(
                icon: "dollarsign.circle",
                title: "Large Expenses Only (>$100)",
                isActive: minimumAmount == 100
            ) {
                applyLargeExpensesFilter()
            }
        }
        
        // Amount Filters
        Section(header: Text("Amount Range (Optional)"), footer: Text("Filter transactions by amount. Useful for excluding small purchases or focusing on large expenses.")) {
            HStack {
                Text("Minimum")
                Spacer()
                TextField("No limit", text: $minAmountString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: minAmountString) { newValue in
                        minimumAmount = Double(newValue)
                    }
            }
            
            HStack {
                Text("Maximum")
                Spacer()
                TextField("No limit", text: $maxAmountString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: maxAmountString) { newValue in
                        maximumAmount = Double(newValue)
                    }
            }
        }
        
        // Account Selection
        if !data.accounts.isEmpty {
            Section(header: Text("Include Accounts"), footer: Text("Select accounts to include in this view. Unselected accounts will be excluded.")) {
                ForEach(accountsByType, id: \.type) { section in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { selectedAccountIDs.contains(where: { id in section.accounts.contains(where: { $0.id == id }) }) },
                            set: { _ in }
                        )
                    ) {
                        ForEach(section.accounts) { account in
                            Button {
                                toggleSimpleSelection(account.id, in: &selectedAccountIDs)
                            } label: {
                                HStack {
                                    Image(systemName: account.accountType.icon)
                                        .foregroundColor(accountTypeColor(account.accountType))
                                    Text(account.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedAccountIDs.contains(account.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary.opacity(0.3))
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(section.type.rawValue)
                                .fontWeight(.medium)
                            Spacer()
                            let selectedCount = section.accounts.filter { selectedAccountIDs.contains($0.id) }.count
                            Text("\(selectedCount)/\(section.accounts.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        
        // Category Selection (Collapsed by default, only show if user wants to filter)
        Section(header: Text("Categories (Optional)")) {
            DisclosureGroup("Filter by Categories") {
                Button("Include All Categories") {
                    selectedCategoryIDs = Set(data.categories.map { $0.id })
                }
                .font(.caption)
                
                ForEach(data.categories) { category in
                    Button {
                        toggleSimpleSelection(category.id, in: &selectedCategoryIDs)
                    } label: {
                        HStack {
                            Text(category.emoji)
                            Text(category.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCategoryIDs.contains(category.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
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
        
        // Amount Range
        Section(header: Text("Amount Range")) {
            HStack {
                Text("Minimum")
                Spacer()
                TextField("No limit", text: $minAmountString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: minAmountString) { newValue in
                        minimumAmount = Double(newValue)
                    }
            }
            
            HStack {
                Text("Maximum")
                Spacer()
                TextField("No limit", text: $maxAmountString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: maxAmountString) { newValue in
                        maximumAmount = Double(newValue)
                    }
            }
        }
        
        Section(header: Text("Exclude Accounts")) {
            if excludedAccountIDs.isEmpty {
                Text("All accounts included")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            ForEach(data.accounts) { account in
                Button {
                    toggleExclusion(account.id, in: &excludedAccountIDs)
                } label: {
                    HStack {
                        Image(systemName: account.accountType.icon)
                            .foregroundColor(accountTypeColor(account.accountType))
                        Text(account.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if excludedAccountIDs.contains(account.id) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        
        Section(header: Text("Exclude Categories")) {
            if excludedCategoryIDs.isEmpty {
                Text("All categories included")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            ForEach(data.categories) { category in
                Button {
                    toggleExclusion(category.id, in: &excludedCategoryIDs)
                } label: {
                    HStack {
                        Text(category.emoji)
                        Text(category.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if excludedCategoryIDs.contains(category.id) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        
        if !data.tags.isEmpty {
            Section(header: Text("Exclude Tags")) {
                if excludedTagIDs.isEmpty {
                    Text("All tags included")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                ForEach(data.tags) { tag in
                    Button {
                        toggleExclusion(tag.id, in: &excludedTagIDs)
                    } label: {
                        HStack {
                            Text(tag.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if excludedTagIDs.contains(tag.id) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var accountsByType: [(type: AccountType, accounts: [Account])] {
        let typeOrder: [AccountType] = [.debit, .goal, .budget, .debt]
        
        return typeOrder.compactMap { type in
            let accountsOfType = data.accounts
                .filter { $0.accountType == type }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return accountsOfType.isEmpty ? nil : (type, accountsOfType)
        }
    }
    
    private func accountTypeColor(_ type: AccountType) -> Color {
        switch type {
        case .debit:  return .primary
        case .goal:   return .blue
        case .budget: return .purple
        case .debt:   return .orange
        }
    }
    
    private func toggleSimpleSelection(_ id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
    }
    
    private func toggleExclusion(_ id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
    }
    
    private func initializeSimpleSelections() {
        // Convert current exclusions to inclusions
        selectedAccountIDs = Set(data.accounts.map { $0.id }).subtracting(excludedAccountIDs)
        selectedCategoryIDs = Set(data.categories.map { $0.id }).subtracting(excludedCategoryIDs)
        selectedTagIDs = Set(data.tags.map { $0.id }).subtracting(excludedTagIDs)
    }
    
    private func convertSimpleToExclusion() {
        // Convert inclusions back to exclusions
        excludedAccountIDs = Set(data.accounts.map { $0.id }).subtracting(selectedAccountIDs)
        excludedCategoryIDs = Set(data.categories.map { $0.id }).subtracting(selectedCategoryIDs)
        excludedTagIDs = Set(data.tags.map { $0.id }).subtracting(selectedTagIDs)
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
        let debitAccountIDs = data.accounts.filter { !$0.isCredit }.map { $0.id }
        selectedAccountIDs = Set(debitAccountIDs)
    }
    
    private func applyLargeExpensesFilter() {
        if minimumAmount == 100 {
            // Toggle off
            minimumAmount = nil
            minAmountString = ""
        } else {
            // Toggle on
            minimumAmount = 100
            minAmountString = "100"
        }
    }
    
    private func initializeAmountStrings() {
        if let min = minimumAmount {
            minAmountString = String(format: "%.2f", min)
        }
        if let max = maximumAmount {
            maxAmountString = String(format: "%.2f", max)
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
                Text(title)
                    .foregroundColor(.primary)
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
                        .onSubmit {
                            if canSave {
                                saveAndDismiss()
                            }
                        }
                }
                
                Section(header: Text("This View Includes")) {
                    if excludedAccountIDs.isEmpty && excludedCategoryIDs.isEmpty && excludedTagIDs.isEmpty && !excludeOutliers {
                        Text("All transactions")
                            .foregroundColor(.secondary)
                    } else {
                        if !excludedAccountIDs.isEmpty {
                            Text("Excludes \(excludedAccountIDs.count) account(s)")
                                .font(.caption)
                        }
                        if !excludedCategoryIDs.isEmpty {
                            Text("Excludes \(excludedCategoryIDs.count) category(ies)")
                                .font(.caption)
                        }
                        if !excludedTagIDs.isEmpty {
                            Text("Excludes \(excludedTagIDs.count) tag(s)")
                                .font(.caption)
                        }
                        if excludeOutliers {
                            Text("Excludes outlier transactions")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Save View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
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
        !presetName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveAndDismiss() {
        onSave(presetName)
        dismiss()
    }
}
