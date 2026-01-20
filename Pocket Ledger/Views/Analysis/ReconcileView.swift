import SwiftUI

struct ReconcileView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    // Tracks the user's manual input for each account
    @State private var actualBalanceInputs: [UUID: String] = [:]
    
    // State for the adjustment sheet (replaced alert with sheet for more detail)
    @State private var accountToAdjust: Account?
    @State private var difference: Double = 0
    @State private var showingAdjustmentSheet = false
    
    // Filter state
    @State private var showOnlyWithDifferences = false
    
    // MARK: - Focus State
    @FocusState private var focusedAccountID: UUID?
    
    // MARK: - Filtered Accounts
    
    private var displayedAccounts: [Account] {
        let accounts = data.accounts.sorted { lhs, rhs in
            // Sort by account type, then alphabetically
            let typeOrder: [AccountType] = [.debit, .goal, .budget, .debt]
            let lhsIndex = typeOrder.firstIndex(of: lhs.accountType) ?? 999
            let rhsIndex = typeOrder.firstIndex(of: rhs.accountType) ?? 999
            
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        
        if showOnlyWithDifferences {
            return accounts.filter { account in
                if let diff = calculateDifference(for: account), abs(diff) > 0.01 {
                    return true
                }
                return false
            }
        }
        
        return accounts
    }
    
    // MARK: - Grouped Accounts
    
    private var accountsByType: [(type: AccountType, accounts: [Account])] {
        let typeOrder: [AccountType] = [.debit, .goal, .budget, .debt]
        
        return typeOrder.compactMap { type in
            let accountsOfType = displayedAccounts.filter { $0.accountType == type }
            return accountsOfType.isEmpty ? nil : (type, accountsOfType)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Instructions
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter the actual balance from your bank/wallet for each account.")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("Pocket Ledger will create adjustment transactions to sync with reality.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Summary Stats
                if differenceSummary.count > 0 || differenceSummary.total != 0 {
                    Section(header: Text("Summary")) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Accounts with differences")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(differenceSummary.count)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Total difference")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(differenceSummary.total.formattedCurrency(symbol: currencySymbol))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(differenceSummary.total > 0 ? .green : .red)
                            }
                        }
                    }
                }
                
                // MARK: - Filter Toggle
                Section {
                    Toggle("Show only accounts with differences", isOn: $showOnlyWithDifferences)
                        .disabled(!hasPendingDifferences)
                }
                
                // MARK: - Account List (Grouped by Type)
                ForEach(accountsByType, id: \.type) { section in
                    Section(header: Text(section.type.rawValue)) {
                        ForEach(Array(section.accounts.enumerated()), id: \.element.id) { index, account in
                            accountRow(for: account, at: indexInAll(account))
                        }
                    }
                }
            }
            .navigationTitle("Reconcile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if hasPendingDifferences {
                        Button("Fix All") {
                            fixAllDifferences()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .sheet(isPresented: $showingAdjustmentSheet) {
                if let account = accountToAdjust {
                    AdjustmentDetailSheet(
                        account: account,
                        difference: difference,
                        currencySymbol: currencySymbol,
                        onConfirm: { categoryID in
                            createAdjustment(categoryID: categoryID)
                        }
                    )
                }
            }
            .decimalPadToolbar()
            .onAppear {
                // Pre-fill with current balances as starting point
                for account in data.accounts {
                    if actualBalanceInputs[account.id] == nil {
                        actualBalanceInputs[account.id] = String(format: "%.2f", data.balance(for: account))
                    }
                }
                
                // Auto-focus on first account
                if let firstAccount = displayedAccounts.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        focusedAccountID = firstAccount.id
                    }
                }
            }
        }
    }
    
    // MARK: - Account Row
    
    @ViewBuilder
    private func accountRow(for account: Account, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Account name with type icon
            HStack {
                Image(systemName: account.accountType.icon)
                    .foregroundColor(accountTypeColor(account.accountType))
                Text(account.name)
                    .font(.headline)
            }
            
            // Balance comparison
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Balance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                        .font(.subheadline)
                        .monospacedDigit()
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actual Balance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("0.00", text: Binding(
                        get: { actualBalanceInputs[account.id] ?? "" },
                        set: { actualBalanceInputs[account.id] = $0 }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .focused($focusedAccountID, equals: account.id)
                    .onSubmit {
                        handleAccountSubmit(currentIndex: index)
                    }
                }
                
                Spacer()
            }
            
            // Difference indicator + action
            if let diff = calculateDifference(for: account), abs(diff) > 0.01 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Difference")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: diff > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundColor(diff > 0 ? .green : .red)
                                .font(.caption)
                            Text(abs(diff).formattedCurrency(symbol: currencySymbol))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(diff > 0 ? .green : .red)
                            Text(diff > 0 ? "(missing inflow)" : "(missing outflow)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        accountToAdjust = account
                        difference = diff
                        showingAdjustmentSheet = true
                    } label: {
                        Text("Fix")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(8)
                .background(diff > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)
            } else if actualBalanceInputs[account.id] != nil && !actualBalanceInputs[account.id]!.isEmpty {
                // Show checkmark if entered and matches
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Balanced")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    
    private func indexInAll(_ account: Account) -> Int {
        displayedAccounts.firstIndex(where: { $0.id == account.id }) ?? 0
    }
    
    private func calculateDifference(for account: Account) -> Double? {
        guard let input = actualBalanceInputs[account.id],
              !input.isEmpty,
              let actual = Double(input) else { return nil }
        let system = data.balance(for: account)
        return actual - system
    }
    
    private var hasPendingDifferences: Bool {
        data.accounts.contains { account in
            if let diff = calculateDifference(for: account), abs(diff) > 0.01 {
                return true
            }
            return false
        }
    }
    
    private var differenceSummary: (count: Int, total: Double) {
        var count = 0
        var total: Double = 0
        
        for account in data.accounts {
            if let diff = calculateDifference(for: account), abs(diff) > 0.01 {
                count += 1
                total += diff
            }
        }
        
        return (count, total)
    }
    
    private func accountTypeColor(_ type: AccountType) -> Color {
        switch type {
        case .debit:  return .primary
        case .goal:   return .blue
        case .budget: return .purple
        case .debt:   return .orange
        }
    }
    
    // MARK: - Focus Chain Logic
    
    private func handleAccountSubmit(currentIndex: Int) {
        let nextIndex = currentIndex + 1
        
        if nextIndex < displayedAccounts.count {
            let nextAccount = displayedAccounts[nextIndex]
            focusedAccountID = nextAccount.id
        } else {
            focusedAccountID = nil
        }
    }
    
    // MARK: - Adjustment Logic
    
    private func fixAllDifferences() {
        for account in data.accounts {
            if let diff = calculateDifference(for: account), abs(diff) > 0.01 {
                createAdjustmentFor(account: account, difference: diff, categoryID: nil)
            }
        }
        
        actualBalanceInputs.removeAll()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }
    
    private func createAdjustment(categoryID: UUID?) {
        guard let account = accountToAdjust else { return }
        createAdjustmentFor(account: account, difference: difference, categoryID: categoryID)
        
        actualBalanceInputs[account.id] = nil
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func createAdjustmentFor(account: Account, difference: Double, categoryID: UUID?) {
        let type: TransactionType = difference > 0 ? .inflow : .outflow
        let amount = abs(difference)
        
        // Determine category
        let finalCategoryID: UUID
        
        if let providedID = categoryID {
            finalCategoryID = providedID
        } else {
            // Auto-select category
            let validCategories = data.categories.filter { $0.type.rawValue == type.rawValue }
            
            var targetCategory = validCategories.first { $0.name == "Other" }
            if targetCategory == nil {
                targetCategory = validCategories.first { $0.name == "Adjustment" }
            }
            if targetCategory == nil {
                targetCategory = validCategories.first
            }
            
            guard let category = targetCategory else { return }
            finalCategoryID = category.id
        }
        
        data.addTransaction(
            type: type,
            accountID: account.id,
            categoryID: finalCategoryID,
            tagIDs: [],
            amount: amount,
            date: Date(),
            isOutlier: true // Mark reconciliation adjustments as outliers by default
        )
    }
}

// MARK: - Adjustment Detail Sheet

struct AdjustmentDetailSheet: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    let account: Account
    let difference: Double
    let currencySymbol: String
    let onConfirm: (UUID?) -> Void
    
    @State private var selectedCategoryID: UUID?
    @State private var markAsOutlier: Bool = true
    
    private var transactionType: TransactionType {
        difference > 0 ? .inflow : .outflow
    }
    
    private var validCategories: [Category] {
        data.categories.filter { $0.type.rawValue == transactionType.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Adjustment Details")) {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(account.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(transactionType == .inflow ? "Inflow" : "Outflow")
                            .foregroundColor(transactionType == .inflow ? .green : .red)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text(abs(difference).formattedCurrency(symbol: currencySymbol))
                            .fontWeight(.bold)
                    }
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Auto-select").tag(nil as UUID?)
                        ForEach(validCategories) { category in
                            HStack {
                                Text(category.emoji)
                                Text(category.name)
                            }
                            .tag(category.id as UUID?)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Toggle("Mark as Outlier", isOn: $markAsOutlier)
                }
                footer: {
                    Text("Recommended: Exclude reconciliation adjustments from statistics by marking them as outliers.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What This Does")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("Creates a \(transactionType == .inflow ? "inflow" : "outflow") transaction of \(abs(difference).formattedCurrency(symbol: currencySymbol)) to bring '\(account.name)' balance in line with your actual balance.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Create Adjustment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onConfirm(selectedCategoryID)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            // Auto-select "Other" or "Adjustment" category if available
            if selectedCategoryID == nil {
                if let other = validCategories.first(where: { $0.name == "Other" }) {
                    selectedCategoryID = other.id
                } else if let adjustment = validCategories.first(where: { $0.name == "Adjustment" }) {
                    selectedCategoryID = adjustment.id
                }
            }
        }
    }
}
