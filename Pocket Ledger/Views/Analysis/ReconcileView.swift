import SwiftUI

struct ReconcileInputView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    let selectedIDs: Set<UUID>
    
    // User Input: Maps Target ID (Account or Group) -> Input String
    @State private var balanceInputs: [UUID: String] = [:]
    
    // Logic: Which target is currently being fixed?
    @State private var targetToAdjust: ReconcileTarget?
    @State private var differenceToAdjust: Double = 0
    
    // Sheet States
    @State private var showingAdjustmentSheet = false
    
    // Model B Logic: If adjusting a group, we need to pick an account
    @State private var showingGroupTargetPicker = false
    @State private var selectedAccountForGroupAdjustment: Account?
    
    // MARK: - Unified Target Model
    enum ReconcileTarget: Identifiable, Hashable {
        case account(Account)
        case group(AccountGroup)
        
        var id: UUID {
            switch self {
            case .account(let a): return a.id
            case .group(let g): return g.id
            }
        }
        
        var name: String {
            switch self {
            case .account(let a): return a.name
            case .group(let g): return g.name
            }
        }
        
        // Helper to get system balance
        func systemBalance(in data: AppData) -> Double {
            switch self {
            case .account(let a): return data.balance(for: a)
            case .group(let g): return data.groupBalance(g)
            }
        }
    }
    
    // Computed list of targets based on selection
    private var targets: [ReconcileTarget] {
        var result: [ReconcileTarget] = []
        
        for id in selectedIDs {
            if let group = data.accountGroups.first(where: { $0.id == id }) {
                result.append(.group(group))
            } else if let account = data.accounts.first(where: { $0.id == id }) {
                result.append(.account(account))
            }
        }
        // Sort by name
        return result.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            // Instructions
            Section {
                Text("Enter the actual total balance for each selected item.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // The Input List
            ForEach(targets) { target in
                targetRow(target)
            }
        }
        .navigationTitle("Reconcile")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        // SHEET 1: Adjustment Details (Category, Notes)
        .sheet(isPresented: $showingAdjustmentSheet) {
            if let target = targetToAdjust {
                AdjustmentDetailSheet(
                    targetName: target.name,
                    difference: differenceToAdjust,
                    currencySymbol: currencySymbol,
                    onConfirm: { categoryID in
                        finalizeAdjustment(categoryID: categoryID)
                    }
                )
            }
        }
        // SHEET 2: Model B Specific - Pick Account for Group Adjustment
        .confirmationDialog("Apply Adjustment To...", isPresented: $showingGroupTargetPicker, titleVisibility: .visible) {
            if case .group(let group) = targetToAdjust {
                let eligibleAccounts = getAccountsRecursive(for: group)
                
                ForEach(eligibleAccounts) { account in
                    Button(account.name) {
                        selectedAccountForGroupAdjustment = account
                        // Once account is picked, proceed to standard adjustment sheet
                        showingAdjustmentSheet = true
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    targetToAdjust = nil
                }
            }
        } message: {
            Text("Since you are reconciling a group, please select which account contains the discrepancy.")
        }
        .decimalPadToolbar()
        .onAppear {
            initializeInputs()
        }
    }
    
    // MARK: - Row Component
    
    @ViewBuilder
    private func targetRow(_ target: ReconcileTarget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if case .group = target {
                    Image(systemName: "folder.fill").foregroundColor(.purple)
                } else {
                    Image(systemName: "building.columns").foregroundColor(.blue)
                }
                Text(target.name).font(.headline)
            }
            
            // Input Area
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("System").font(.caption2).foregroundColor(.secondary)
                    Text(target.systemBalance(in: data).formattedCurrency(symbol: currencySymbol))
                        .font(.subheadline)
                        .monospacedDigit()
                }
                
                Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
                
                VStack(alignment: .leading) {
                    Text("Actual").font(.caption2).foregroundColor(.secondary)
                    TextField("0.00", text: Binding(
                        get: { balanceInputs[target.id] ?? "" },
                        set: { balanceInputs[target.id] = $0 }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                }
                
                Spacer()
            }
            
            // Difference & Action
            if let diff = calculateDifference(for: target), abs(diff) > 0.01 {
                HStack {
                    Text("Diff: \(diff > 0 ? "+" : "")\(diff.formattedCurrency(symbol: currencySymbol))")
                        .font(.subheadline)
                        .foregroundColor(diff > 0 ? .green : .red)
                    
                    Spacer()
                    
                    Button("Fix") {
                        startFixProcess(for: target, difference: diff)
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            } else if let input = balanceInputs[target.id], !input.isEmpty {
                 HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Balanced").font(.caption).foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Logic
    
    private func initializeInputs() {
        for target in targets {
            let balance = target.systemBalance(in: data)
            balanceInputs[target.id] = String(format: "%.2f", balance)
        }
    }
    
    private func calculateDifference(for target: ReconcileTarget) -> Double? {
        guard let text = balanceInputs[target.id], let actual = Double(text) else { return nil }
        return actual - target.systemBalance(in: data)
    }
    
    private func startFixProcess(for target: ReconcileTarget, difference: Double) {
        targetToAdjust = target
        differenceToAdjust = difference
        
        switch target {
        case .account(let account):
            // Simple case: We know the account
            selectedAccountForGroupAdjustment = account
            showingAdjustmentSheet = true
            
        case .group:
            // Model B case: We must ask user for the account
            showingGroupTargetPicker = true
        }
    }
    
    private func finalizeAdjustment(categoryID: UUID?) {
        guard let account = selectedAccountForGroupAdjustment else { return }
        
        // Create Transaction
        let type: TransactionType = differenceToAdjust > 0 ? .inflow : .outflow
        
        // Auto-category fallback
        var finalCatID = categoryID
        if finalCatID == nil {
            finalCatID = data.categories.first(where: { $0.name == "Adjustment" || $0.name == "Other" })?.id
            if finalCatID == nil { finalCatID = data.categories.first?.id }
        }
        
        if let catID = finalCatID {
            data.addTransaction(
                type: type,
                accountID: account.id,
                categoryID: catID,
                tagIDs: [],
                amount: abs(differenceToAdjust),
                date: Date(),
                isOutlier: true
            )
        }
        
        // Reset Input for this target to match new reality
        if let target = targetToAdjust {
            // We update the input to match the (now corrected) system balance
            // effectively "clearing" the error visually
            balanceInputs[target.id] = nil
        }
        
        // Cleanup
        targetToAdjust = nil
        selectedAccountForGroupAdjustment = nil
    }
    
    // Recursive helper to find all concrete accounts inside a group
    private func getAccountsRecursive(for group: AccountGroup) -> [Account] {
        var results: [Account] = []
        let allIDs = group.allAccountIDs(in: data.accountGroups, accounts: data.accounts)
        for id in allIDs {
            if let acc = data.accounts.first(where: { $0.id == id }) {
                results.append(acc)
            }
        }
        return results
    }
}

// Reuse the existing AdjustmentDetailSheet (it is generic enough)
// Minor tweak: pass `targetName` string instead of `Account` object to make it compatible
struct AdjustmentDetailSheet: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    let targetName: String
    let difference: Double
    let currencySymbol: String
    let onConfirm: (UUID?) -> Void
    
    @State private var selectedCategoryID: UUID?
    @State private var markAsOutlier: Bool = true
    
    private var transactionType: TransactionType {
        difference > 0 ? .inflow : .outflow
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Adjustment Summary")) {
                    HStack {
                        Text("Target")
                        Spacer()
                        Text(targetName).foregroundColor(.secondary)
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
                        ForEach(data.categories.filter { $0.type.rawValue == transactionType.rawValue }) { cat in
                            Text(cat.emoji + " " + cat.name).tag(cat.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("Confirm Adjustment")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onConfirm(selectedCategoryID)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
