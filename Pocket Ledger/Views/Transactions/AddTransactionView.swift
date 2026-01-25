import SwiftUI

struct AddTransactionView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    // Mode
    let initialType: TransactionType?
    let template: TransactionTemplate?
    let editingTransaction: Transaction?

    // MARK: - Form State
    @State private var type: TransactionType
    
    // Transaction Data
    @State private var accountID: UUID?
    @State private var transferTargetAccountID: UUID?
    @State private var categoryID: UUID?
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var amountString: String = ""
    @State private var date: Date = Date()
    @State private var installmentCount: Int = 1
    @State private var isOutlier: Bool = false
    
    // Template State
    @State private var isShowingTemplateSheet: Bool = false
    @State private var templateName: String = ""

    // Sheet State (Half-Menu Triggers)
    @State private var showAccountPicker = false
    @State private var showTransferTargetPicker = false
    @State private var showCategoryPicker = false
    @State private var showTagPicker = false

    // MARK: - Focus State
    enum Field: Hashable {
        case amount
    }
    
    @FocusState private var focusedField: Field?

    // MARK: - Initialiser
    init(initialType: TransactionType? = nil,
         template: TransactionTemplate? = nil,
         editingTransaction: Transaction? = nil) {
        
        self.initialType = initialType
        self.template = template
        self.editingTransaction = editingTransaction
        
        // 1. Determine Initial Type
        var startType: TransactionType = .outflow
        if let edit = editingTransaction {
            startType = edit.type
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
            _selectedTagIDs = State(initialValue: Set(edit.tagIDs))
            _amountString = State(initialValue: String(format: "%.2f", edit.amount))
            _date = State(initialValue: edit.date)
            _isOutlier = State(initialValue: edit.isOutlier)
        } else if let tpl = template {
            _accountID = State(initialValue: tpl.accountID)
            _categoryID = State(initialValue: tpl.categoryID)
            _selectedTagIDs = State(initialValue: Set(tpl.tagIDs))
            _isOutlier = State(initialValue: tpl.isOutlier)
            _transferTargetAccountID = State(initialValue: tpl.transferTargetAccountID)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // SECTION 1: AMOUNT (Color Coded)
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

                // SECTION 4: TAGS
                Section {
                    Button {
                        showTagPicker = true
                    } label: {
                        HStack {
                            Text("Tags")
                            Spacer()
                            if selectedTagIDs.isEmpty {
                                Text("None").foregroundColor(.secondary)
                            } else {
                                Text("\(selectedTagIDs.count) selected")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .foregroundColor(.primary)
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

                Section(header: Text("Options")) {
                    if type != .transfer && editingTransaction == nil {
                        Stepper(value: $installmentCount, in: 1...12) {
                            Text("Installments: \(installmentCount)")
                        }
                    }

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
            // MARK: - Alert for transaction
            .alert("Save Template", isPresented: $isShowingTemplateSheet) {
                TextField("Template Name", text: $templateName)
                Button("Save") { saveTemplate() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter a name for this template.")
            }
            // MARK: - Half-Menu Sheets
            .sheet(isPresented: $showAccountPicker) {
                advanceAfterAccountSelection()
            } content: {
                NavigationStack {
                    SelectionView(title: type == .transfer ? "From Account" : "Account", items: data.accounts, selectedID: $accountID)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showTransferTargetPicker) {
                advanceAfterTransferTargetSelection()
            } content: {
                NavigationStack {
                    SelectionView(title: "To Account", items: data.accounts.filter { $0.id != accountID }, selectedID: $transferTargetAccountID)
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
            .sheet(isPresented: $showTagPicker) {
                NavigationStack {
                    MultiSelectionView(title: "Tags", items: data.tags, selectedIDs: $selectedTagIDs)
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                if amountString.isEmpty && editingTransaction == nil {
                    focusedField = .amount
                }
            }
            .decimalPadToolbar()
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
        
        data.addTemplate(
            name: name,
            type: type,
            accountID: accountID,
            categoryID: categoryID,
            tagIDs: Array(selectedTagIDs),
            isOutlier: isOutlier,
            transferTargetAccountID: type == .transfer ? transferTargetAccountID : nil
        )
    }
    
    private var filteredCategories: [Category] {
        data.categories.filter {
            $0.type.rawValue == type.rawValue &&
            $0.name != "Transfer"
        }
    }

    private func accountName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return data.accounts.first(where: { $0.id == id })?.name
    }

    private func categoryName(for id: UUID?) -> String? {
        guard let id = id else { return nil }
        return data.categories.first(where: { $0.id == id })?.name
    }
    
    private func calculateAmount(_ input: String) -> Double {
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/")
        let sanitized = input.components(separatedBy: allowed.inverted).joined()
        if sanitized.isEmpty { return 0 }
        guard let lastChar = sanitized.last, lastChar.isNumber else {
            return Double(sanitized) ?? 0
        }
        let expression = NSExpression(format: sanitized)
        if let result = expression.expressionValue(with: nil, context: nil) as? Double {
            return result
        } else if let intResult = expression.expressionValue(with: nil, context: nil) as? Int {
            return Double(intResult)
        }
        return Double(sanitized) ?? 0
    }

    private var canSave: Bool {
        let amount = calculateAmount(amountString)
        guard amount > 0 else { return false }
        
        if type == .transfer {
            return accountID != nil && transferTargetAccountID != nil && accountID != transferTargetAccountID
        } else {
            return accountID != nil && categoryID != nil
        }
    }
    
    // MARK: - Focus Chain Logic (Updated)
    
    private enum NavigationStep {
        case account
        case secondary // Category or Transfer Target
        case tags
    }
    
    /// Checks current fields and automatically presents the next empty picker.
    /// If a field is already filled, it falls through to the next step.
    private func checkAndPresentNextField(startingFrom step: NavigationStep) {
        switch step {
        case .account:
            if accountID == nil {
                showAccountPicker = true
                return
            }
            fallthrough // Proceed to check next
            
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
            fallthrough
            
        case .tags:
            if selectedTagIDs.isEmpty {
                showTagPicker = true
                return
            }
            // If tags are filled, we stop (flow complete, user can review/save)
        }
    }
    
    private func handleAmountSubmit() {
        focusedField = nil
        // Start checking from the first field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            checkAndPresentNextField(startingFrom: .account)
        }
    }
    
    private func advanceAfterAccountSelection() {
        guard accountID != nil else { return }
        // Start checking from the next logical field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            checkAndPresentNextField(startingFrom: .secondary)
        }
    }
    
    private func advanceAfterTransferTargetSelection() {
        guard transferTargetAccountID != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            checkAndPresentNextField(startingFrom: .tags)
        }
    }
    
    private func advanceAfterCategorySelection() {
        guard categoryID != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            checkAndPresentNextField(startingFrom: .tags)
        }
    }
    
    private func saveAndAddAnother() {
        saveTransaction(shouldDismiss: false)
        amountString = ""
        selectedTagIDs = []
        isOutlier = false
        focusedField = .amount
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func saveTransaction(shouldDismiss: Bool = true) {
        let amount = calculateAmount(amountString)
        let tags = Array(selectedTagIDs)

        if type == .transfer {
            guard let fromAcc = accountID, let toAcc = transferTargetAccountID else { return }
            
            let outCatID = ensureTransferCategory(type: .outflow)
            let inCatID = ensureTransferCategory(type: .inflow)
            
            data.addTransaction(type: .outflow, accountID: fromAcc, categoryID: outCatID, tagIDs: tags, amount: amount, date: date, isOutlier: isOutlier)
            data.addTransaction(type: .inflow, accountID: toAcc, categoryID: inCatID, tagIDs: tags, amount: amount, date: date, isOutlier: isOutlier)
            
        } else {
            guard let accountID = accountID, let categoryID = categoryID else { return }
            
            if let existing = editingTransaction {
                var updated = existing
                updated.type = type
                updated.accountID = accountID
                updated.categoryID = categoryID
                updated.tagIDs = tags
                updated.amount = amount
                updated.date = date
                updated.isOutlier = isOutlier
                data.updateTransaction(updated)
            } else {
                if installmentCount <= 1 {
                    data.addTransaction(type: type, accountID: accountID, categoryID: categoryID, tagIDs: tags, amount: amount, date: date, isOutlier: isOutlier)
                } else {
                    let perInstallment = amount / Double(installmentCount)
                    for i in 0..<installmentCount {
                        let instDate = Calendar.current.date(byAdding: .month, value: i, to: date) ?? date
                        data.addTransaction(type: type, accountID: accountID, categoryID: categoryID, tagIDs: tags, amount: perInstallment, date: instDate, isOutlier: isOutlier)
                    }
                }
            }
        }
        
        if shouldDismiss {
            dismiss()
        }
    }
    
    private func ensureTransferCategory(type: CategoryType) -> UUID {
        if let existing = data.categories.first(where: { $0.name == "Transfer" && $0.type == type }) {
            return existing.id
        }
        let newCat = Category(name: "Transfer", type: type, emoji: "⇆")
        data.categories.append(newCat)
        data.save()
        return newCat.id
    }
}
