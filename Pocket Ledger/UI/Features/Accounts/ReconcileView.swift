import SwiftUI
import UIKit // Needed for Haptics

struct ReconcileInputView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    let selectedIDs: Set<UUID>
    var onComplete: () -> Void
    
    // User Input: Maps Target ID -> Input String
    @State private var balanceInputs: [UUID: String] = [:]
    
    // Logic: Which target is currently being fixed?
    @State private var targetToAdjust: ReconcileTarget?
    @State private var differenceToAdjust: Decimal = 0
    
    // Sheet States
    @State private var showingAdjustmentSheet = false
    @State private var showingGroupTargetPicker = false
    @State private var selectedAccountForGroupAdjustment: Account?
    
    // Feedback States
    @State private var showingSuccessAlert = false
    @State private var reconciledCount = 0
    
    @FocusState private var focusedFieldID: UUID?
    
    // MARK: - Computed Binding
    private var activeMathBinding: Binding<String> {
        Binding {
            guard let id = focusedFieldID else { return "" }
            return balanceInputs[id] ?? ""
        } set: { newValue in
            guard let id = focusedFieldID else { return }
            balanceInputs[id] = newValue
        }
    }
    
    // MARK: - Target Model
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
        
        /// Whether this target is a credit-type account (debt or limit).
        /// Groups return false since they contain mixed account types.
        var isCredit: Bool {
            switch self {
            case .account(let a): return a.isCredit
            case .group: return false
            }
        }
        
        func systemBalance(accountStore: AccountStore, transactions: [Transaction]) -> Decimal {
            switch self {
            case .account(let a):
                return FinancialCalculator.balance(for: a, in: transactions)
            case .group(let g):
                return FinancialCalculator.groupBalance(
                    g,
                    in: accountStore.accountGroups,
                    accounts: accountStore.accounts,
                    transactions: transactions
                )
            }
        }
    }
    
    private var targets: [ReconcileTarget] {
        var result: [ReconcileTarget] = []
        for id in selectedIDs {
            if let group = accountStore.accountGroups.first(where: { $0.id == id }) {
                result.append(.group(group))
            } else if let account = accountStore.accounts.first(where: { $0.id == id }) {
                result.append(.account(account))
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section {
                Text("Enter the actual balance for each item. If the amounts match, it will be marked as verified.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(targets) { target in
                targetRow(target)
            }
        }
        .navigationTitle("Reconcile")
        .safeAreaInset(edge: .bottom) {
            VStack {
                Button(action: handleDone) {
                    Text("Finish Reconciliation")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .shadow(radius: 4, y: 2)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .mathPadToolbar(for: activeMathBinding)
        .onAppear { initializeInputs() }
        
        // --- ALERTS & SHEETS ---
        
        .alert("Verification Complete", isPresented: $showingSuccessAlert) {
            Button("OK") { onComplete() }
        } message: {
            Text("\(reconciledCount) accounts have been marked as verified.")
        }
        
        .sheet(isPresented: $showingAdjustmentSheet) {
            if let target = targetToAdjust {
                let name = selectedAccountForGroupAdjustment?.name ?? target.name
                let isCredit = selectedAccountForGroupAdjustment?.isCredit ?? target.isCredit
                let resolvedType: TransactionType = isCredit
                    ? (differenceToAdjust > 0 ? .outflow : .inflow)
                    : (differenceToAdjust > 0 ? .inflow : .outflow)
                
                AdjustmentDetailSheet(
                    targetName: name,
                    difference: differenceToAdjust,
                    transactionType: resolvedType,
                    currencySymbol: currencySymbol,
                    onConfirm: { categoryID in
                        finalizeAdjustment(categoryID: categoryID)
                    }
                )
            }
        }
        
        .confirmationDialog("Apply Adjustment To...", isPresented: $showingGroupTargetPicker, titleVisibility: .visible) {
            if case .group(let group) = targetToAdjust {
                let eligibleAccounts = getAccountsRecursive(for: group)
                ForEach(eligibleAccounts) { account in
                    Button(account.name) {
                        selectedAccountForGroupAdjustment = account
                        showingAdjustmentSheet = true
                    }
                }
                Button("Cancel", role: .cancel) { targetToAdjust = nil }
            }
        } message: {
            Text("Select which account in the group contains the discrepancy.")
        }
    }
    
    // MARK: - Row View
    private func targetRow(_ target: ReconcileTarget) -> some View {
        let systemBal = target.systemBalance(accountStore: accountStore, transactions: transactionStore.transactions)
        let binding = Binding<String>(
            get: { balanceInputs[target.id] ?? "" },
            set: { balanceInputs[target.id] = $0 }
        )
        
        // Determine the reconciliation status for this row
        let status = reconcileStatus(for: target, systemBalance: systemBal)
        
        return VStack(alignment: .leading, spacing: 12) {
            // Row 1: Name and system balance
            HStack {
                if case .group = target {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.purple)
                        .font(.subheadline)
                }
                Text(target.name)
                    .fontWeight(.medium)
                Spacer()
            }
            
            // Row 2: System balance display
            HStack {
                Text("Balance in Pocket Ledger")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(systemBal.formattedCurrency(symbol: currencySymbol))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Row 3: Actual balance input
            HStack {
                Text("Actual Balance")
                    .font(.subheadline)
                
                Spacer()
                
                TextField("Enter amount", text: binding)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.weight(.medium))
                    .focused($focusedFieldID, equals: target.id)
                    .submitLabel(.next)
                    .onSubmit {
                        moveToNextField(from: target.id)
                    }
            }
            
            // Row 4: Status feedback
            switch status {
            case .empty:
                EmptyView()
                
            case .matched:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Balances match")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
            case .mismatched(let diff):
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Difference: \(diff.formattedCurrency(symbol: currencySymbol))")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    
                    Button {
                        prepareForAdjustment(target: target, diff: diff)
                    } label: {
                        HStack {
                            Image(systemName: "plus.forwardslash.minus")
                            Text("Create Adjustment Transaction")
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Status Helper
    
    private enum RowStatus {
        case empty
        case matched
        case mismatched(Decimal)
    }
    
    private func reconcileStatus(for target: ReconcileTarget, systemBalance: Decimal) -> RowStatus {
        guard let input = balanceInputs[target.id], !input.isEmpty else {
            return .empty
        }
        let actual = MathParser.calculate(input)
        let diff = actual - systemBalance
        
        if abs(diff) < 0.01 {
            return .matched
        } else {
            return .mismatched(diff)
        }
    }
    
    // MARK: - Logic Helpers
    
    private func moveToNextField(from currentID: UUID) {
        let currentTargets = targets
        if let idx = currentTargets.firstIndex(where: { $0.id == currentID }) {
            let nextIdx = idx + 1
            if nextIdx < currentTargets.count {
                focusedFieldID = currentTargets[nextIdx].id
            } else {
                focusedFieldID = nil
            }
        }
    }
    
    private func initializeInputs() { }
    
    private func prepareForAdjustment(target: ReconcileTarget, diff: Decimal) {
        targetToAdjust = target
        differenceToAdjust = diff
        
        if case .group = target {
            showingGroupTargetPicker = true
        } else {
            showingAdjustmentSheet = true
        }
    }
    
    private func getAccountsRecursive(for group: AccountGroup) -> [Account] {
        let ids = group.allAccountIDs(in: accountStore.accountGroups, accounts: accountStore.accounts)
        return accountStore.accounts.filter { ids.contains($0.id) }
    }
    
    // MARK: - Done Action
    
    private func handleDone() {
        let count = commitReconciliation()
        
        if count > 0 {
            reconciledCount = count
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            showingSuccessAlert = true
        } else {
            onComplete()
        }
    }
    
    private func commitReconciliation() -> Int {
        var updatedCount = 0
        for (id, input) in balanceInputs {
            guard !input.isEmpty else { continue }
            guard let target = targets.first(where: { $0.id == id }) else { continue }
            
            let actual = MathParser.calculate(input)
            let system = target.systemBalance(accountStore: accountStore, transactions: transactionStore.transactions)
            
            if abs(actual - system) < 0.01 {
                switch target {
                case .account(let account):
                    accountStore.markAccountAsReconciled(account.id)
                    updatedCount += 1
                case .group(let group):
                    let childAccounts = getAccountsRecursive(for: group)
                    for child in childAccounts {
                        accountStore.markAccountAsReconciled(child.id)
                        updatedCount += 1
                    }
                }
            }
        }
        return updatedCount
    }
    
    private func finalizeAdjustment(categoryID: UUID?) {
        guard let target = targetToAdjust else { return }
        
        let targetAccount: Account?
        if let groupAcc = selectedAccountForGroupAdjustment {
            targetAccount = groupAcc
        } else if case .account(let acc) = target {
            targetAccount = acc
        } else {
            return
        }
        
        guard let account = targetAccount else { return }
        
        // FIX: Determine correct transaction type based on account type.
        // For debit/goal accounts (isCredit = false):
        //   balance = initial + inflows - outflows
        //   positive diff (actual > system) → need inflow to increase balance
        //   negative diff (actual < system) → need outflow to decrease balance
        //
        // For limit/debt accounts (isCredit = true):
        //   balance = initial + outflows - inflows
        //   positive diff (actual > system) → need outflow to increase balance
        //   negative diff (actual < system) → need inflow to decrease balance
        let type: TransactionType
        if account.isCredit {
            // Credit accounts: reverse the logic
            type = differenceToAdjust > 0 ? .outflow : .inflow
        } else {
            // Debit accounts: standard logic
            type = differenceToAdjust > 0 ? .inflow : .outflow
        }
        let amount = abs(differenceToAdjust)
        
        let finalCategoryID: UUID
        if let userCat = categoryID {
            finalCategoryID = userCat
        } else {
            finalCategoryID = ensureAdjustmentCategory(type: type)
        }
        
        transactionStore.addTransaction(
            type: type,
            accountID: account.id,
            categoryID: finalCategoryID,
            tagIDs: [],
            amount: amount,
            date: Date(),
            isOutlier: false
        )
        
        accountStore.markAccountAsReconciled(account.id)
        
        // Update the input field to reflect the new (now-matching) balance
        if let targetID = targetToAdjust?.id {
            let newSystem = targetToAdjust?.systemBalance(
                accountStore: accountStore,
                transactions: transactionStore.transactions
            ) ?? 0
            balanceInputs[targetID] = "\(newSystem)"
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        targetToAdjust = nil
        selectedAccountForGroupAdjustment = nil
        showingAdjustmentSheet = false
        showingGroupTargetPicker = false
    }
    
    private func ensureAdjustmentCategory(type: TransactionType) -> UUID {
        let name = "Reconciliation Adjustment"
        if let existing = transactionStore.categories.first(where: { $0.name == name && $0.type.rawValue == type.rawValue }) {
            return existing.id
        }
        let catType = CategoryType(rawValue: type.rawValue) ?? .outflow
        let newCat = Category(name: name, type: catType, emoji: "⚖️")
        transactionStore.categories.append(newCat)
        transactionStore.save()
        return newCat.id
    }
}

struct AdjustmentDetailSheet: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    
    let targetName: String
    let difference: Decimal
    let transactionType: TransactionType
    let currencySymbol: String
    let onConfirm: (UUID?) -> Void
    
    @State private var selectedCategoryID: UUID?
    
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
                        Text("Difference")
                        Spacer()
                        Text(abs(difference).formattedCurrency(symbol: currencySymbol))
                            .fontWeight(.bold)
                    }
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Auto-select").tag(nil as UUID?)
                        ForEach(transactionStore.categories.filter { $0.type.rawValue == transactionType.rawValue }) { cat in
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
