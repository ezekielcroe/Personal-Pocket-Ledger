import SwiftUI
import UIKit // Needed for Haptics

import SwiftUI
import UIKit // Needed for Haptics

struct ReconcileInputView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    // NOTE: Removed @Environment(\.dismiss) because we delegate dismissal to the parent
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
                Button("Done") {
                    handleDone()
                }
            }
        }
        .mathPadToolbar(for: activeMathBinding)
        .onAppear { initializeInputs() }
        
        // --- ALERTS & SHEETS ---
        
        // 1. Success Feedback Alert
        .alert("Verification Complete", isPresented: $showingSuccessAlert) {
            // CRITICAL FIX: Call onComplete() here, NOT dismiss()
            Button("OK") { onComplete() }
        } message: {
            Text("\(reconciledCount) accounts have been marked as verified.")
        }
        
        // 2. Adjustment Sheet
        .sheet(isPresented: $showingAdjustmentSheet) {
            if let target = targetToAdjust {
                let name = selectedAccountForGroupAdjustment?.name ?? target.name
                AdjustmentDetailSheet(
                    targetName: name,
                    difference: differenceToAdjust,
                    currencySymbol: currencySymbol,
                    onConfirm: { categoryID in
                        finalizeAdjustment(categoryID: categoryID)
                    }
                )
            }
        }
        
        // 3. Group Picker
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
        
        return VStack(spacing: 8) {
            HStack {
                if case .group = target {
                    Image(systemName: "folder.fill").foregroundColor(.purple)
                }
                Text(target.name).fontWeight(.medium)
                Spacer()
                Text("System: \(systemBal.formattedCurrency(symbol: currencySymbol))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Actual:").foregroundColor(.secondary)
                
                TextField("0.00", text: binding)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedFieldID, equals: target.id)
                
                if let input = balanceInputs[target.id], !input.isEmpty {
                    let actual = MathParser.calculate(input)
                    let diff = actual - systemBal
                    
                    if abs(diff) < 0.01 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button {
                            prepareForAdjustment(target: target, diff: diff)
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
            // Success State
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
        
        let accountID: UUID
        if let groupAcc = selectedAccountForGroupAdjustment {
            accountID = groupAcc.id
        } else if case .account(let acc) = target {
            accountID = acc.id
        } else { return }
        
        let type: TransactionType = differenceToAdjust > 0 ? .inflow : .outflow
        let amount = abs(differenceToAdjust)
        
        let finalCategoryID: UUID
        if let userCat = categoryID {
            finalCategoryID = userCat
        } else {
            finalCategoryID = ensureAdjustmentCategory(type: type)
        }
        
        transactionStore.addTransaction(
            type: type,
            accountID: accountID,
            categoryID: finalCategoryID,
            tagIDs: [],
            amount: amount,
            date: Date(),
            isOutlier: false
        )
        
        accountStore.markAccountAsReconciled(accountID)
        
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
