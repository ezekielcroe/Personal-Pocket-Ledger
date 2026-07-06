import SwiftUI
import UIKit

struct AddTransactionView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @EnvironmentObject var accountStore: AccountStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    // Mode
    let initialType: TransactionType?
    let template: TransactionTemplate?
    let editingTransaction: Transaction?
    /// When set, the form opens pre-filled as a NEW transaction (date = today).
    let duplicatingTransaction: Transaction?

    @State private var linkedTransaction: Transaction?

    // MARK: - Form State
    @State private var type: TransactionType
    
    // Transaction Data
    @State private var accountID: UUID?
    @State private var transferTargetAccountID: UUID?
    @State private var categoryID: UUID?
    @State private var amountString: String = ""
    @State private var date: Date = Date()
    @State private var isOutlier: Bool = false
    @State private var remark: String = ""
    
    // Autocomplete suggestions for the remark field
    @State private var remarkSuggestionList: [String] = []
    
    // Template State
    @State private var isShowingTemplateSheet: Bool = false
    @State private var templateName: String = ""

    // Sheet State (Half-Menu Triggers)
    @State private var showAccountPicker = false
    @State private var showTransferTargetPicker = false
    @State private var showCategoryPicker = false

    // MARK: - Focus State
    enum Field: Hashable {
        case amount
        case remark
    }
    
    @FocusState private var focusedField: Field?

    // MARK: - Initialiser
    init(initialType: TransactionType? = nil,
         template: TransactionTemplate? = nil,
         editingTransaction: Transaction? = nil,
         duplicatingTransaction: Transaction? = nil) {
        
        self.initialType = initialType
        self.template = template
        self.editingTransaction = editingTransaction
        self.duplicatingTransaction = duplicatingTransaction
        
        // 1. Determine Initial Type
        var startType: TransactionType = .outflow
        if let edit = editingTransaction {
            startType = edit.type
        } else if let dup = duplicatingTransaction {
            startType = dup.type
        } else if let tpl = template {
            startType = tpl.type
        } else if let t = initialType {
            startType = t
        }
        _type = State(initialValue: startType)

        // 2. Pre-fill Data
        if let edit = editingTransaction {
            _accountID = State(initialValue: edit.accountID)
            _categoryID = State(initialValue: edit.categoryID)
            let doubleAmount = NSDecimalNumber(decimal: edit.amount).doubleValue
            _amountString = State(initialValue: String(format: "%.2f", doubleAmount))
            _date = State(initialValue: edit.date)
            _isOutlier = State(initialValue: edit.isOutlier)
            _remark = State(initialValue: edit.remark)
            // Note: Transfer target is loaded in onAppear via findLinkedTransaction
        } else if let dup = duplicatingTransaction {
            // Copy everything except the date, which defaults to today.
            _accountID = State(initialValue: dup.accountID)
            _categoryID = State(initialValue: dup.categoryID)
            let doubleAmount = NSDecimalNumber(decimal: dup.amount).doubleValue
            _amountString = State(initialValue: String(format: "%.2f", doubleAmount))
            _isOutlier = State(initialValue: dup.isOutlier)
            _remark = State(initialValue: dup.remark)
            // Note: If this is one leg of a transfer, onAppear resolves the
            // partner leg and switches the form into Transfer mode.
        } else if let tpl = template {
            _accountID = State(initialValue: tpl.accountID)
            _categoryID = State(initialValue: tpl.categoryID)
            _isOutlier = State(initialValue: tpl.isOutlier)
            _remark = State(initialValue: tpl.remark)
            _transferTargetAccountID = State(initialValue: tpl.transferTargetAccountID)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // SECTION 1: AMOUNT
                Section(header: Text("Amount")) {
                    TextField("0.00", text: $amountString)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.system(size: 44, weight: .bold))
                        .multilineTextAlignment(.center)
                        .focused($focusedField, equals: .amount)
                        .foregroundColor(amountColor)
                        .onSubmit {
                            handleAmountSubmit()
                        }
                }
                .listRowBackground(Color.clear)

                // SECTION 2: TYPE
                Section {
                    if editingTransaction == nil {
                        Picker("Type", selection: $type) {
                            ForEach(TransactionType.allCases) { t in
                                Text(t.rawValue.capitalized).tag(t)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    } else if let _ = linkedTransaction {
                        // If editing a linked transfer, show a locked label
                        HStack {
                            Text("Transaction Type")
                            Spacer()
                            HStack {
                                Image(systemName: "link")
                                Text("Linked Transfer")
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // ACCOUNT SELECTION
                    if type == .transfer {
                        Button {
                            showAccountPicker = true
                        } label: {
                            HStack {
                                Text("From Account")
                                Spacer()
                                Text(accountName(for: accountID) ?? "Select")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                        
                        Button {
                            showTransferTargetPicker = true
                        } label: {
                            HStack {
                                Text("To Account")
                                Spacer()
                                Text(accountName(for: transferTargetAccountID) ?? "Select")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    } else {
                        Button {
                            showAccountPicker = true
                        } label: {
                            HStack {
                                Text("Account")
                                Spacer()
                                Text(accountName(for: accountID) ?? "Select")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                // SECTION 3: CATEGORY
                if type != .transfer {
                    Section {
                        Button {
                            showCategoryPicker = true
                        } label: {
                            HStack {
                                Text("Category")
                                Spacer()
                                Text(categoryName(for: categoryID) ?? "Select")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                // SECTION 4: REMARK
                Section(header: Text("Remark")) {
                    TextField("Optional — payee or note", text: $remark)
                        .focused($focusedField, equals: .remark)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .onSubmit {
                            // Return completes the top suggestion while a word
                            // is in progress; on an empty fragment it dismisses.
                            if !currentRemarkFragment.isEmpty,
                               let top = remarkSuggestionList.first {
                                applyRemarkSuggestion(top)
                            } else {
                                remark = remark.trimmingCharacters(in: .whitespaces)
                                focusedField = nil
                            }
                        }
                        .onKeyPress(.tab) {
                            // Hardware keyboards (iPad / Mac): Tab completes
                            // the top suggestion.
                            if let top = remarkSuggestionList.first {
                                applyRemarkSuggestion(top)
                                return .handled
                            }
                            return .ignored
                        }
                    
                    // Autocomplete: past remarks ranked by frequency, then recency
                    if focusedField == .remark {
                        ForEach(remarkSuggestionList, id: \.self) { suggestion in
                            Button {
                                applyRemarkSuggestion(suggestion)
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(suggestion)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                // SECTION 5: DATE
                Section {
                    HStack(spacing: 12) {
                        Button {
                            date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                        } label: {
                            Text("Yesterday")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            date = Date()
                        } label: {
                            Text("Today")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                // SECTION 6: OPTIONS
                Section(header: Text("Options")) {
                    Toggle("Flag as Outlier", isOn: $isOutlier)
                    
                    if editingTransaction == nil {
                        Button {
                            templateName = ""
                            isShowingTemplateSheet = true
                        } label: {
                            Text("Save as Template")
                        }
                    }
                }
            }
            .formToolbar(
                title: navTitle,
                canSave: canSave,
                onSave: { saveTransaction(shouldDismiss: true) },
                onCancel: { dismiss() },
                onSaveAndNew: editingTransaction == nil ? { saveAndAddAnother() } : nil
            )
            .alert("Save Template", isPresented: $isShowingTemplateSheet) {
                TextField("Template Name", text: $templateName)
                Button("Save") { saveTemplate() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter a name for this template.")
            }
            .sheet(isPresented: $showAccountPicker) {
                advanceAfterAccountSelection()
            } content: {
                NavigationStack {
                    // Filter accounts based on transaction type
                    SelectionView(
                        title: type == .transfer ? "From Account" : "Account",
                        items: accountsForSourceSelection,
                        selectedID: $accountID
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showTransferTargetPicker) {
                advanceAfterTransferTargetSelection()
            } content: {
                NavigationStack {
                    // All accounts except the source (Debt accounts ARE valid targets)
                    SelectionView(
                        title: "To Account",
                        items: accountStore.accounts.filter { $0.id != accountID && !$0.isArchived },
                        selectedID: $transferTargetAccountID
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCategoryPicker) {
                advanceAfterCategorySelection()
            } content: {
                NavigationStack {
                    SelectionView(title: "Category", items: filteredCategories, selectedID: $categoryID)
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                if amountString.isEmpty && editingTransaction == nil {
                    focusedField = .amount
                }
                // NEW: If editing, try to find the linked transaction to populate "Target Account"
                if let edit = editingTransaction,
                   let linkedID = edit.linkedTransactionID,
                   let partner = transactionStore.transactions.first(where: { $0.id == linkedID }) {
                    self.linkedTransaction = partner
                    self.transferTargetAccountID = partner.accountID
                    self.type = .transfer // Ensure UI shows as transfer
                }
                // NEW: If duplicating one leg of a transfer, reconstruct the
                // whole transfer. The outflow leg is always the "From" side,
                // so orientation is correct no matter which leg was swiped.
                if let dup = duplicatingTransaction,
                   let linkedID = dup.linkedTransactionID,
                   let partner = transactionStore.transactions.first(where: { $0.id == linkedID }) {
                    self.type = .transfer
                    if dup.type == .outflow {
                        self.accountID = dup.accountID
                        self.transferTargetAccountID = partner.accountID
                    } else {
                        self.accountID = partner.accountID
                        self.transferTargetAccountID = dup.accountID
                    }
                }
            }
            .mathPadToolbar(for: keyboardToolbarBinding)
            .onChange(of: remark) { _, _ in
                refreshRemarkSuggestions()
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue == .remark {
                    refreshRemarkSuggestions()
                }
            }
        }
    }
    
    // MARK: - Keyboard Toolbar Routing
    
    /// The math toolbar (+ - * /) appends to whichever field owns the keyboard.
    /// Without this, tapping an operator while typing a remark would silently
    /// append it to the hidden amount field.
    private var keyboardToolbarBinding: Binding<String> {
        Binding {
            focusedField == .remark ? remark : amountString
        } set: { newValue in
            if focusedField == .remark {
                remark = newValue
            } else {
                amountString = newValue
            }
        }
    }
    
    // MARK: - Remark Autocomplete
    
    /// The word currently being typed: everything after the last whitespace.
    private var currentRemarkFragment: String {
        if let lastSpace = remark.lastIndex(where: { $0.isWhitespace }) {
            return String(remark[remark.index(after: lastSpace)...])
        }
        return remark
    }
    
    private func refreshRemarkSuggestions() {
        remarkSuggestionList = transactionStore.remarkWordSuggestions(completing: currentRemarkFragment)
    }
    
    /// Completes the word being typed, keeping everything before it, and
    /// appends a space so the next word starts clean. Focus is re-asserted
    /// because pressing Return resigns it before this runs; the trailing
    /// space is trimmed on save.
    private func applyRemarkSuggestion(_ word: String) {
        if let lastSpace = remark.lastIndex(where: { $0.isWhitespace }) {
            remark = String(remark[...lastSpace]) + word + " "
        } else {
            remark = word + " "
        }
        DispatchQueue.main.async {
            focusedField = .remark
        }
    }
    
    // MARK: - Account Filtering
    
    /// Accounts available for selection as transaction source.
        private var accountsForSourceSelection: [Account] {
            let activeAccounts = accountStore.accounts.filter { !$0.isArchived }
            
            switch type {
            case .inflow:
                // Money can flow INTO any account
                return activeAccounts
                
            case .outflow:
                // STRICT LOCK:
                // 1. Cannot spend directly from Debt (existing rule)
                // 2. Cannot spend directly from Goal (new rule)
                return activeAccounts.filter {
                    $0.accountType != .debt &&
                    $0.accountType != .goal
                }
                
            case .transfer:
                // EMERGENCY ACCESS:
                // Allow transfers FROM Goal accounts to other accounts.
                // Still prevent transfers FROM pure Debt accounts (like mortgages).
                return activeAccounts.filter { $0.accountType != .debt }
            }
        }
    
    // MARK: - Helpers
    
    private var amountColor: Color {
        switch type {
        case .inflow: return .green
        case .outflow: return .primary
        case .transfer: return .blue
        }
    }
    
    private var navTitle: String {
        if let _ = editingTransaction { return "Edit Transaction" }
        return type == .transfer ? "New Transfer" : "New Transaction"
    }

    // MARK: - Logic
    
    private func saveTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        transactionStore.addTemplate(
            name: name,
            type: type,
            accountID: accountID,
            categoryID: categoryID,
            isOutlier: isOutlier,
            transferTargetAccountID: type == .transfer ? transferTargetAccountID : nil,
            remark: remark.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    private var filteredCategories: [Category] {
        transactionStore.categories.filter {
            $0.type.rawValue == type.rawValue &&
            $0.name != "Transfer"
        }
    }

    private func accountName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return accountStore.accounts.first(where: { $0.id == id })?.name
    }

    private func categoryName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return transactionStore.categories.first(where: { $0.id == id })?.name
    }
    
    private var canSave: Bool {
        let amount = MathParser.calculate(amountString)
        guard amount > 0 else { return false }
        
        if type == .transfer {
            return accountID != nil && transferTargetAccountID != nil && accountID != transferTargetAccountID
        } else {
            return accountID != nil && categoryID != nil
        }
    }
    
    private enum NavigationStep {
        case account
        case secondary
    }
    
    private func checkAndPresentNextField(startingFrom step: NavigationStep) {
        switch step {
        case .account:
            if accountID == nil {
                showAccountPicker = true
                return
            }
            fallthrough
            
        case .secondary:
            if type == .transfer {
                if transferTargetAccountID == nil {
                    showTransferTargetPicker = true
                    return
                }
            } else {
                if categoryID == nil {
                    showCategoryPicker = true
                    return
                }
            }
        }
    }
    
    private func handleAmountSubmit() {
        focusedField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            checkAndPresentNextField(startingFrom: .account)
        }
    }
    
    private func advanceAfterAccountSelection() {
        guard accountID != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            checkAndPresentNextField(startingFrom: .secondary)
        }
    }
    
    /// After the transfer target is chosen, hand focus to the remark field
    /// so typing can start immediately. The delay lets the sheet finish
    /// dismissing before the keyboard comes up.
    private func advanceAfterTransferTargetSelection() {
        guard transferTargetAccountID != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            focusedField = .remark
        }
    }
    
    /// After a category is chosen, hand focus to the remark field so typing
    /// can start immediately.
    private func advanceAfterCategorySelection() {
        guard categoryID != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            focusedField = .remark
        }
    }
    
    private func saveAndAddAnother() {
        saveTransaction(shouldDismiss: false)
        amountString = ""
        isOutlier = false
        remark = ""
        focusedField = .amount
    }

    private func saveTransaction(shouldDismiss: Bool = true) {
        let amount = MathParser.calculate(amountString)
        let trimmedRemark = remark.trimmingCharacters(in: .whitespacesAndNewlines)

        if type == .transfer {
            guard let fromAcc = accountID, let toAcc = transferTargetAccountID else { return }
            
            let outCatID = ensureTransferCategory(type: .outflow)
            let inCatID = ensureTransferCategory(type: .inflow)
            
            if var existing = editingTransaction, let linkedID = existing.linkedTransactionID {
                // UPDATE EXISTING LINKED PAIR — already uses updateTransaction(), no change needed
                existing.accountID = fromAcc
                existing.amount = amount
                existing.date = date
                existing.isOutlier = isOutlier
                existing.remark = trimmedRemark
                transactionStore.updateTransaction(existing)
                
                if var partner = transactionStore.transactions.first(where: { $0.id == linkedID }) {
                    partner.accountID = toAcc
                    partner.amount = amount
                    partner.date = date
                    partner.isOutlier = isOutlier
                    partner.remark = trimmedRemark
                    transactionStore.updateTransaction(partner)
                }
                
            } else {
                // CREATE NEW LINKED PAIR
                // Use pre-generated IDs so the two transactions can reference each other.
                let id1 = UUID.v7()
                let id2 = UUID.v7()

                // Use addTransaction() so recomputeBalances() is called for each leg.
                // The debouncer coalesces the two resulting save() calls into one disk write.
                transactionStore.addTransaction(
                    id: id1,
                    linkedTransactionID: id2,
                    type: .outflow,
                    accountID: fromAcc,
                    categoryID: outCatID,
                    amount: amount,
                    date: date,
                    isOutlier: isOutlier,
                    remark: trimmedRemark
                )
                transactionStore.addTransaction(
                    id: id2,
                    linkedTransactionID: id1,
                    type: .inflow,
                    accountID: toAcc,
                    categoryID: inCatID,
                    amount: amount,
                    date: date,
                    isOutlier: isOutlier,
                    remark: trimmedRemark
                )
            }
            
        } else {
            // NORMAL TRANSACTION — unchanged, already correct
            guard let accountID = accountID, let categoryID = categoryID else { return }
            
            if let existing = editingTransaction {
                var updated = existing
                updated.type = type
                updated.accountID = accountID
                updated.categoryID = categoryID
                updated.amount = amount
                updated.date = date
                updated.isOutlier = isOutlier
                updated.remark = trimmedRemark
                transactionStore.updateTransaction(updated)
            } else {
                transactionStore.addTransaction(
                    type: type,
                    accountID: accountID,
                    categoryID: categoryID,
                    amount: amount,
                    date: date,
                    isOutlier: isOutlier,
                    remark: trimmedRemark
                )
            }
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        if shouldDismiss {
            dismiss()
        }
    }

    private func ensureTransferCategory(type: CategoryType) -> UUID {
        if let existing = transactionStore.categories.first(where: { $0.name == "Transfer" && $0.type == type }) {
            return existing.id
        }
        // Use addCategory() for consistency — previously used direct array mutation
        transactionStore.addCategory(name: "Transfer", type: type, emoji: "⇆")
        return transactionStore.categories.last(where: { $0.name == "Transfer" && $0.type == type })!.id
    }
}
