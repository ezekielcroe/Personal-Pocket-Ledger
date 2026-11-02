import SwiftUI
import UIKit

/// The transaction form. Design intent ("Capture is the job"): the user
/// still makes every decision — type, amount, account, category — but the
/// form removes mechanical effort around those decisions: the last-used
/// account is pre-selected, common categories are one tap away, past
/// remarks complete as you type, and "Last time" offers (never applies)
/// what you did the previous time.
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
    @State private var remarkSuggestionList: [RemarkSuggestion] = []

    // Template State
    @State private var isShowingTemplateSheet: Bool = false
    @State private var templateName: String = ""

    // Sheet State (Half-Menu Triggers)
    @State private var showAccountPicker = false
    @State private var showTransferTargetPicker = false
    @State private var showCategoryPicker = false

    // Batch entry ("Save &")
    @State private var savedBanner: SavedBanner?
    @State private var sessionSavedCount = 0

    private struct SavedBanner: Equatable {
        let id = UUID()
        let text: String
    }

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
            _amountString = State(initialValue: Self.plainAmount(edit.amount))
            _date = State(initialValue: edit.date)
            _isOutlier = State(initialValue: edit.isOutlier)
            _remark = State(initialValue: edit.remark)
            // Note: Transfer target is loaded in onAppear via the linked transaction
        } else if let dup = duplicatingTransaction {
            // Copy everything except the date, which defaults to today.
            _accountID = State(initialValue: dup.accountID)
            _categoryID = State(initialValue: dup.categoryID)
            _amountString = State(initialValue: Self.plainAmount(dup.amount))
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
                // SECTION 1: TYPE — chosen before the amount, so the account
                // and category steps that follow already know the rules.
                if editingTransaction == nil {
                    Section {
                        Picker("Type", selection: $type) {
                            ForEach(TransactionType.allCases) { t in
                                Text(t.rawValue.capitalized).tag(t)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }

                // SECTION 2: AMOUNT
                Section(header: Text("Amount")) {
                    VStack(spacing: 4) {
                        TextField("0.00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 44, weight: .bold))
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .amount)
                            .foregroundColor(amountColor)
                            .onSubmit {
                                // Hardware keyboards; the on-screen pad uses "Next".
                                handleAmountSubmit()
                            }

                        // Live result while a calculation is being typed.
                        if let preview = amountPreview {
                            Text(preview.text)
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(preview.isValid ? .secondary : .orange)
                                .transition(.opacity)
                        }
                    }
                }
                .listRowBackground(Color.clear)

                // SECTION 3: ACCOUNT
                Section {
                    if editingTransaction != nil, linkedTransaction != nil {
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

                    if type == .transfer {
                        pickerRow(label: "From Account", value: accountName(for: accountID)) {
                            showAccountPicker = true
                        }
                        pickerRow(label: "To Account", value: accountName(for: transferTargetAccountID)) {
                            showTransferTargetPicker = true
                        }
                    } else {
                        pickerRow(label: "Account", value: accountName(for: accountID)) {
                            showAccountPicker = true
                        }
                    }
                }

                // SECTION 4: CATEGORY — common categories as one-tap chips,
                // with the full searchable list behind "More".
                if type != .transfer {
                    Section(header: Text("Category")) {
                        let chips = categoryChips
                        if chips.isEmpty {
                            pickerRow(label: "Category", value: categoryName(for: categoryID)) {
                                showCategoryPicker = true
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(chips) { category in
                                        CategoryChip(category: category,
                                                     isSelected: category.id == categoryID) {
                                            selectCategory(category.id)
                                        }
                                    }
                                    if showsMoreCategoriesChip(besides: chips) {
                                        Button {
                                            showCategoryPicker = true
                                        } label: {
                                            Label("More", systemImage: "ellipsis")
                                                .font(.subheadline)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.4)))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("More categories")
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        }
                    }
                }

                // SECTION 5: REMARK
                Section(header: Text("Remark")) {
                    TextField("Optional — payee or note", text: $remark)
                        .focused($focusedField, equals: .remark)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .onSubmit(handleRemarkSubmit)
                        .onKeyPress(.tab) {
                            // Hardware keyboards (iPad / Mac): Tab completes
                            // the top suggestion — prefix matches only.
                            if let top = acceptableSuggestion {
                                applyRemarkSuggestion(top)
                                return .handled
                            }
                            return .ignored
                        }

                    if focusedField == .remark {
                        ForEach(remarkSuggestionList) { suggestion in
                            Button {
                                applyRemarkSuggestion(suggestion)
                            } label: {
                                suggestionRow(suggestion)
                            }
                        }
                    }

                    lastTimeHint
                }

                // SECTION 6: DATE
                Section {
                    HStack(spacing: 12) {
                        dateChip("Yesterday", isSelected: Calendar.current.isDateInYesterday(date)) {
                            date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                        }
                        dateChip("Today", isSelected: Calendar.current.isDateInToday(date)) {
                            date = Date()
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)

                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                // SECTION 7: OPTIONS
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
                onSaveAndNew: editingTransaction == nil ? { saveAndAddAnother() } : nil,
                disabledReason: saveBlockedReason,
                allowsInteractiveDismiss: isPristine
            )
            .overlay(alignment: .top) { savedBannerView }
            .toolbar {
                // Operators only make sense in the amount field; the remark
                // field gets a plain Done.
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .amount {
                        HStack(spacing: 18) {
                            operatorButton("plus", insert: "+", label: "Plus")
                            operatorButton("minus", insert: "-", label: "Minus")
                            operatorButton("multiply", insert: "*", label: "Times")
                            operatorButton("divide", insert: "/", label: "Divided by")
                        }
                        .font(.body.weight(.bold))
                        Spacer()
                        Button("Next") { handleAmountSubmit() }
                            .fontWeight(.bold)
                    } else {
                        Spacer()
                        Button("Done") {
                            remark = remark.trimmingCharacters(in: .whitespaces)
                            focusedField = nil
                        }
                        .fontWeight(.bold)
                    }
                }
            }
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
                // If editing one leg of a transfer, resolve the partner leg.
                // The outflow leg is always the "From" side, so orientation
                // is correct no matter which leg was tapped in the list.
                if let edit = editingTransaction,
                   let linkedID = edit.linkedTransactionID,
                   let partner = transactionStore.transactions.first(where: { $0.id == linkedID }) {
                    self.linkedTransaction = partner
                    self.type = .transfer // Ensure UI shows as transfer
                    if edit.type == .outflow {
                        self.accountID = edit.accountID
                        self.transferTargetAccountID = partner.accountID
                    } else {
                        self.accountID = partner.accountID
                        self.transferTargetAccountID = edit.accountID
                    }
                }
                // If duplicating one leg of a transfer, reconstruct the
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
                // A template or duplicate may carry selections that are no
                // longer allowed (e.g. the account has since become a Goal,
                // or was archived). Clear them so the form shows "Select",
                // then pre-select the last-used account if none is set.
                if editingTransaction == nil {
                    clearInvalidSelections()
                    applyDefaultAccountIfNeeded()
                }
            }
            // Account and category rules depend on the type. Without this,
            // picking a Goal account under Inflow and then switching to
            // Outflow would save an outflow from a Goal — bypassing the lock.
            .onChange(of: type) { _, _ in
                if editingTransaction == nil {
                    clearInvalidSelections()
                    applyDefaultAccountIfNeeded()
                }
                refreshRemarkSuggestions()
            }
            .onChange(of: remark) { _, _ in
                refreshRemarkSuggestions()
            }
            .onChange(of: categoryID) { _, _ in
                refreshRemarkSuggestions()
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue == .remark {
                    refreshRemarkSuggestions()
                }
            }
        }
    }

    // MARK: - Row Builders

    private func pickerRow(label: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                Spacer()
                Text(value ?? "Select")
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(.primary)
    }

    private func dateChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func operatorButton(_ systemImage: String, insert symbol: String, label: String) -> some View {
        Button {
            amountString.append(symbol)
        } label: {
            Image(systemName: systemImage)
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func suggestionRow(_ suggestion: RemarkSuggestion) -> some View {
        HStack(spacing: 10) {
            if suggestion.kind == .phrase,
               let id = suggestion.usualCategoryID,
               let emoji = transactionStore.categories.first(where: { $0.id == id })?.emoji,
               !emoji.isEmpty {
                Text(emoji)
                    .font(.caption)
            } else {
                Image(systemName: suggestion.kind == .phrase ? "clock.arrow.circlepath" : "text.cursor")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(suggestion.text)
                .foregroundColor(.primary)
            Spacer()
        }
    }

    // MARK: - Amount Preview

    /// "= $22.50" while the amount contains a calculation; nil for a plain
    /// number. A leading minus alone doesn't count as a calculation.
    private var amountPreview: (text: String, isValid: Bool)? {
        let trimmed = amountString.trimmingCharacters(in: .whitespaces)
        let operators: Set<Character> = ["+", "-", "*", "/", "×", "÷"]
        guard trimmed.dropFirst().contains(where: { operators.contains($0) }) else { return nil }
        if let value = MathParser.evaluate(trimmed) {
            return ("= " + value.formattedCurrency(symbol: currencySymbol), true)
        }
        return ("Not a valid calculation", false)
    }

    /// A Decimal as an editable string with two decimals and a "." point,
    /// e.g. 5.2 → "5.20". MathParser reads "." in every locale.
    private static func plainAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    // MARK: - Category Chips

    /// Up to five categories for the current type, most used first. The
    /// selected category is always shown, even if it isn't a frequent one.
    private var categoryChips: [Category] {
        guard let categoryType = CategoryType(rawValue: type.rawValue) else { return [] }
        var chips = transactionStore.suggestedCategories(for: categoryType, limit: 5)
        if let id = categoryID,
           !chips.contains(where: { $0.id == id }),
           let selected = transactionStore.categories.first(where: { $0.id == id }) {
            chips = [selected] + chips.prefix(4)
        }
        return chips
    }

    /// "More" appears only when some categories aren't already chips.
    private func showsMoreCategoriesChip(besides chips: [Category]) -> Bool {
        guard let categoryType = CategoryType(rawValue: type.rawValue) else { return false }
        let shown = chips.filter { !$0.isSystemCategory && !$0.isArchived }.count
        return transactionStore.selectableCategoryCount(for: categoryType) > shown
    }

    private func selectCategory(_ id: UUID) {
        categoryID = id
        UISelectionFeedbackGenerator().selectionChanged()
        // Move on to the remark unless one is already written.
        if remark.trimmingCharacters(in: .whitespaces).isEmpty {
            focusedField = .remark
        }
    }

    // MARK: - Remark Autocomplete

    private var currentRemarkFragment: String {
        RemarkIndex.currentFragment(of: remark)
    }

    private func refreshRemarkSuggestions() {
        remarkSuggestionList = transactionStore.remarkSuggestions(
            for: remark,
            type: type,
            categoryID: type == .transfer ? nil : categoryID
        )
    }

    /// The suggestion Return/Tab may accept (see `canAutoAccept`): never a
    /// "contains" match, never on an empty word, never over a finished word.
    private var acceptableSuggestion: RemarkSuggestion? {
        guard !currentRemarkFragment.isEmpty else { return nil }
        return remarkSuggestionList.first(where: \.canAutoAccept)
    }

    private func handleRemarkSubmit() {
        if let top = acceptableSuggestion {
            applyRemarkSuggestion(top)
        } else {
            remark = remark.trimmingCharacters(in: .whitespaces)
            focusedField = nil
        }
    }

    /// A phrase replaces the remark; a word completes the word being typed.
    /// Either way a space is appended so typing can continue, and focus is
    /// re-asserted because Return resigns it before this runs. The trailing
    /// space is trimmed on save.
    private func applyRemarkSuggestion(_ suggestion: RemarkSuggestion) {
        switch suggestion.kind {
        case .phrase:
            remark = suggestion.text + " "
        case .word:
            remark = RemarkIndex.textBeforeFragment(of: remark) + suggestion.text + " "
        }
        DispatchQueue.main.async {
            focusedField = .remark
        }
    }

    // MARK: - "Last Time"

    /// The previous transaction with exactly this remark and type, if any.
    /// Offered, never applied automatically: the user taps to accept.
    private var lastTimeMatch: Transaction? {
        guard editingTransaction == nil, type != .transfer else { return nil }
        return transactionStore.lastTransaction(withRemark: remark, type: type)
    }

    @ViewBuilder
    private var lastTimeHint: some View {
        if let last = lastTimeMatch {
            let offerAccount = last.accountID != accountID && isAllowedSource(last.accountID)
            let offerCategory = last.categoryID != categoryID && isAllowedCategory(last.categoryID)
            let offerAmount = amountString.trimmingCharacters(in: .whitespaces).isEmpty

            if offerAccount || offerCategory || offerAmount {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(lastTimeSummary(for: last))
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        if offerAccount || offerCategory {
                            Button(lastTimeApplyLabel(account: offerAccount, category: offerCategory)) {
                                if offerAccount { accountID = last.accountID }
                                if offerCategory { categoryID = last.categoryID }
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                        if offerAmount {
                            Button("Use \(last.amount.formattedCurrency(symbol: currencySymbol))") {
                                amountString = Self.plainAmount(last.amount)
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    }
                    // Bordered styles keep each button separately tappable
                    // inside a Form row.
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func lastTimeSummary(for last: Transaction) -> String {
        var parts: [String] = []
        if let category = transactionStore.categories.first(where: { $0.id == last.categoryID }) {
            parts.append(category.emoji.isEmpty ? category.name : "\(category.emoji) \(category.name)")
        }
        if let name = accountName(for: last.accountID) {
            parts.append(name)
        }
        parts.append(last.amount.formattedCurrency(symbol: currencySymbol))
        parts.append(last.date.formatted(.dateTime.day().month(.abbreviated)))
        return "Last time: " + parts.joined(separator: " · ")
    }

    private func lastTimeApplyLabel(account: Bool, category: Bool) -> String {
        switch (account, category) {
        case (true, true):  return "Use same category & account"
        case (false, true): return "Use same category"
        default:            return "Use same account"
        }
    }

    private func isAllowedSource(_ id: UUID) -> Bool {
        accountsForSourceSelection.contains { $0.id == id }
    }

    private func isAllowedCategory(_ id: UUID) -> Bool {
        filteredCategories.contains { $0.id == id && !$0.isArchived }
    }

    // MARK: - Default Account

    /// Pre-selects the account used by the last transaction of this type,
    /// if it's allowed for the type. Only fills an empty field.
    private func applyDefaultAccountIfNeeded() {
        guard editingTransaction == nil, accountID == nil,
              let id = transactionStore.lastUsedSourceAccountID(for: type),
              isAllowedSource(id) else { return }
        accountID = id
        if type == .transfer, transferTargetAccountID == id {
            transferTargetAccountID = nil
        }
    }

    // MARK: - Saved Banner

    @ViewBuilder
    private var savedBannerView: some View {
        if let banner = savedBanner {
            Label(banner.text, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                .padding(.top, 6)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    /// e.g. "Saved −$4.50 · Starbucks", or "Saved $50.00 · DBS → Amex".
    private func savedSummary() -> String {
        let amount = MathParser.calculate(amountString).formattedCurrency(symbol: currencySymbol)
        let trimmedRemark = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type {
        case .transfer:
            let from = accountName(for: accountID) ?? "?"
            let to = accountName(for: transferTargetAccountID) ?? "?"
            return "Saved \(amount) · \(from) → \(to)"
        case .inflow, .outflow:
            let sign = type == .inflow ? "+" : "−"
            let detail = trimmedRemark.isEmpty ? (categoryName(for: categoryID) ?? "") : trimmedRemark
            return detail.isEmpty ? "Saved \(sign)\(amount)" : "Saved \(sign)\(amount) · \(detail)"
        }
    }

    private func showSavedBanner(_ summary: String) {
        let text = sessionSavedCount > 1 ? "\(summary) (\(sessionSavedCount) saved)" : summary
        let banner = SavedBanner(text: text)
        withAnimation(.spring(duration: 0.3)) { savedBanner = banner }
        UIAccessibility.post(notification: .announcement, argument: text)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if savedBanner?.id == banner.id {
                withAnimation(.easeOut(duration: 0.3)) { savedBanner = nil }
            }
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

    /// True while nothing has been typed, so swiping the sheet away loses
    /// nothing. Edits and duplicates always count as having input.
    private var isPristine: Bool {
        guard editingTransaction == nil, duplicatingTransaction == nil else { return false }
        let initialRemark = (template?.remark ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return amountString.trimmingCharacters(in: .whitespaces).isEmpty &&
            remark.trimmingCharacters(in: .whitespacesAndNewlines) == initialRemark
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

    /// Categories offered for the current type. System categories (Transfer,
    /// Reconciliation Adjustment) are managed by the app and never offered.
    private var filteredCategories: [Category] {
        transactionStore.categories.filter {
            $0.type.rawValue == type.rawValue && !$0.isSystemCategory
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

    private var canSave: Bool { saveBlockedReason == nil }

    /// Why Save is unavailable, in plain words; nil when the form can save.
    private var saveBlockedReason: String? {
        let trimmedAmount = amountString.trimmingCharacters(in: .whitespaces)
        if trimmedAmount.isEmpty { return "Enter an amount" }
        guard let amount = MathParser.evaluate(trimmedAmount) else {
            return "The amount isn't a valid calculation"
        }
        if amount <= 0 { return "The amount must be more than zero" }

        if type == .transfer {
            guard accountID != nil else { return "Choose a From account" }
            guard let target = transferTargetAccountID else { return "Choose a To account" }
            if target == accountID { return "From and To must be different accounts" }
        } else {
            guard accountID != nil else { return "Choose an account" }
            guard categoryID != nil else { return "Choose a category" }
        }

        // New transactions must respect the account rules for their type.
        // Edits are exempt: the type can't change while editing, and an
        // existing record may legitimately sit on a since-archived account.
        if editingTransaction == nil {
            if !isSourceAccountValid { return sourceAccountRule }
            if !isTransferTargetValid { return "Choose a different To account" }
            if !isCategoryValid {
                return type == .inflow ? "Choose an income category" : "Choose a spending category"
            }
        }
        return nil
    }

    /// Explains why the selected source account isn't allowed.
    private var sourceAccountRule: String {
        if let id = accountID, accountStore.accounts.first(where: { $0.id == id })?.isArchived == true {
            return "That account is archived"
        }
        switch type {
        case .outflow:  return "Spending can't come from a Goal or Debt account"
        case .transfer: return "Transfers can't start from a Debt account"
        case .inflow:   return "Choose an active account"
        }
    }

    // MARK: - Selection Validity

    /// The source account is allowed for the current type (e.g. no outflows
    /// from Goal or Debt accounts, no transfers out of Debt). Nil counts as
    /// valid here; "nothing selected" is handled separately.
    private var isSourceAccountValid: Bool {
        guard let id = accountID else { return true }
        return accountsForSourceSelection.contains { $0.id == id }
    }

    /// The transfer target is active and isn't the source account.
    private var isTransferTargetValid: Bool {
        guard type == .transfer, let id = transferTargetAccountID else { return true }
        return id != accountID &&
            accountStore.accounts.contains { $0.id == id && !$0.isArchived }
    }

    /// The category matches the current type and isn't archived.
    /// Transfers don't use a category, so any value is fine there.
    private var isCategoryValid: Bool {
        guard type != .transfer, let id = categoryID else { return true }
        return filteredCategories.contains { $0.id == id && !$0.isArchived }
    }

    /// Clears any selection the current type doesn't allow, so the form
    /// shows "Select" instead of quietly saving an invalid combination.
    private func clearInvalidSelections() {
        if !isSourceAccountValid { accountID = nil }
        if !isTransferTargetValid { transferTargetAccountID = nil }
        if !isCategoryValid { categoryID = nil }
    }

    // MARK: - Step-by-step Flow

    private enum NavigationStep {
        case account
        case secondary
    }

    /// Opens whichever required choice is still missing. Once everything is
    /// chosen, goes straight to the remark (e.g. on the second "Save &"
    /// entry, where account and category carry over).
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
            } else if categoryID == nil {
                // Chips put the common categories one tap away on the form
                // itself; only open the full list when there are none.
                if categoryChips.isEmpty {
                    showCategoryPicker = true
                }
                return
            }
            focusedField = .remark
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

    /// Saves, confirms with a banner, and resets for the next entry. Account,
    /// category, type and date carry over; amount, remark and outlier reset.
    private func saveAndAddAnother() {
        let summary = savedSummary()
        saveTransaction(shouldDismiss: false)
        sessionSavedCount += 1
        showSavedBanner(summary)
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
                // UPDATE EXISTING LINKED PAIR
                // The form always shows the outflow leg as "From". The leg
                // being edited may be either one, so assign accounts by leg
                // type rather than assuming the edited leg is the source.
                let existingIsSource = existing.type == .outflow
                existing.accountID = existingIsSource ? fromAcc : toAcc
                existing.amount = amount
                existing.date = date
                existing.isOutlier = isOutlier
                existing.remark = trimmedRemark
                transactionStore.updateTransaction(existing)
                
                if var partner = transactionStore.transactions.first(where: { $0.id == linkedID }) {
                    partner.accountID = existingIsSource ? toAcc : fromAcc
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
        transactionStore.systemCategoryID(for: .transfer, type: type)
    }
}

// MARK: - Category Chip

/// One-tap category choice on the transaction form.
private struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if !category.emoji.isEmpty {
                    Text(category.emoji)
                }
                Text(category.name)
                    .lineLimit(1)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground),
                        in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
