import SwiftUI

struct ReconcileInputView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    let selectedIDs: Set<UUID>
    
    // User Input: Maps Target ID -> Input String
    @State private var balanceInputs: [UUID: String] = [:]
    
    // Logic: Which target is currently being fixed?
    @State private var targetToAdjust: ReconcileTarget?
    @State private var differenceToAdjust: Double = 0
    
    // Sheet States
    @State private var showingAdjustmentSheet = false
    @State private var showingGroupTargetPicker = false
    @State private var selectedAccountForGroupAdjustment: Account?
    
    // MARK: - KEY FIX: Track which Row ID is focused
    @FocusState private var focusedFieldID: UUID?
    
    // MARK: - Computed Binding for the Toolbar
    // This tells the toolbar: "Apply the + sign to whichever text field is currently focused"
    private var activeMathBinding: Binding<String> {
        Binding {
            guard let id = focusedFieldID else { return "" }
            return balanceInputs[id] ?? ""
        } set: { newValue in
            guard let id = focusedFieldID else { return }
            balanceInputs[id] = newValue
        }
    }
    
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
        
        func systemBalance(in data: AppData) -> Double {
            switch self {
            case .account(let a): return data.balance(for: a)
            case .group(let g): return data.groupBalance(g)
            }
        }
    }
    
    private var targets: [ReconcileTarget] {
        var result: [ReconcileTarget] = []
        for id in selectedIDs {
            if let group = data.accountGroups.first(where: { $0.id == id }) {
                result.append(.group(group))
            } else if let account = data.accounts.first(where: { $0.id == id }) {
                result.append(.account(account))
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section {
                Text("Enter the actual total balance for each selected item.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(targets) { target in
                targetRow(target)
            }
        }
        .navigationTitle("Reconcile")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") { dismiss() }
            }
        }
        // KEY FIX: Pass the dynamic binding to the toolbar
        .mathPadToolbar(for: activeMathBinding)
        .onAppear { initializeInputs() }
        
        // --- SHEETS ---
        
        // 1. Adjustment Details
        .sheet(isPresented: $showingAdjustmentSheet) {
            if let target = targetToAdjust {
                // Placeholder for your AdjustmentDetailSheet
                Text("Adjustment Sheet for \(target.name)")
                // You can paste your AdjustmentDetailSheet implementation here or in a separate file
            }
        }
        
        // 2. Group Account Picker
        .confirmationDialog("Apply Adjustment To...", isPresented: $showingGroupTargetPicker, titleVisibility: .visible) {
            if case .group(let group) = targetToAdjust {
                let eligibleAccounts = getAccountsRecursive(for: group)
                
                ForEach(eligibleAccounts) { account in
                    Button(account.name) {
                        selectedAccountForGroupAdjustment = account
                        showingAdjustmentSheet = true
                    }
                }
                Button("Cancel", role: .cancel) {
                    targetToAdjust = nil
                }
            }
        } message: {
            Text("Select which account in the group contains the discrepancy.")
        }
    }
    
    // MARK: - Row View
    private func targetRow(_ target: ReconcileTarget) -> some View {
        let systemBal = target.systemBalance(in: data)
        // Safe binding to the dictionary
        let binding = Binding<String>(
            get: { balanceInputs[target.id] ?? "" },
            set: { balanceInputs[target.id] = $0 }
        )
        
        return VStack(spacing: 8) {
            HStack {
                Text(target.name)
                    .fontWeight(.medium)
                Spacer()
                // System Balance (Reference)
                Text("System: \(systemBal.formattedCurrency(symbol: currencySymbol))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Actual:")
                    .foregroundColor(.secondary)
                
                TextField("0.00", text: binding)
                    .keyboardType(.numbersAndPunctuation) // Must match MathParser logic
                    .multilineTextAlignment(.trailing)
                    .focused($focusedFieldID, equals: target.id) // KEY: Link focus to ID
                    .onSubmit {
                        checkDiscrepancy(for: target)
                    }
                
                // Status Indicator
                if let input = balanceInputs[target.id], !input.isEmpty {
                    let actual = MathParser.calculate(input)
                    let diff = actual - systemBal
                    
                    if abs(diff) < 0.01 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button {
                            checkDiscrepancy(for: target)
                        } label: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Logic Helpers
    
    private func initializeInputs() {
        for target in targets {
            // Pre-fill with current system balance to make it easier?
            // Or leave empty? Let's leave empty to force "Active Guardianship"
            if balanceInputs[target.id] == nil {
                balanceInputs[target.id] = ""
            }
        }
    }
    
    private func checkDiscrepancy(for target: ReconcileTarget) {
        guard let input = balanceInputs[target.id] else { return }
        let actual = MathParser.calculate(input)
        let system = target.systemBalance(in: data)
        let diff = actual - system
        
        if abs(diff) > 0.01 {
            // Discrepancy found, trigger adjustment flow
            targetToAdjust = target
            differenceToAdjust = diff
            
            if case .group = target {
                showingGroupTargetPicker = true
            } else {
                showingAdjustmentSheet = true
            }
        }
    }
    
    private func getAccountsRecursive(for group: AccountGroup) -> [Account] {
        let ids = group.allAccountIDs(in: data.accountGroups, accounts: data.accounts)
        return data.accounts.filter { ids.contains($0.id) }
    }
    
    private func finalizeAdjustment(categoryID: UUID?) {
        // Your existing logic to create the transaction
        dismiss()
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
