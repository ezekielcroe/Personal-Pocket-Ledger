import SwiftUI

/// Form to add a new account with a name, starting balance, and optional target/installment plan.
struct AddAccountView: View {
    @EnvironmentObject var accountStore: AccountStore
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var initialAmountString: String = ""
    @State private var isCredit: Bool = false
    @State private var targetAmountString: String = ""
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var paymentFrequency: PaymentFrequency = .monthly
    
    @State private var selectedGroupIDs: Set<UUID> = []
    
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    // MARK: - Focus State
    enum Field: Hashable {
        case name
        case amount
        case target
    }
    
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                // SECTION 1: Account Type Toggle
                Section(footer: Text(accountTypeFooter)) {
                    Toggle(isCredit ? "Debt/Credit Account" : "Cash Account", isOn: $isCredit)
                        .onChange(of: isCredit) { _, newValue in
                            // Don't auto-set anything - let user decide
                        }
                }
                
                // SECTION 2: Basic Info
                Section(header: Text("Account Details"), footer: Text(startingBalanceFooter)) {
                    TextField("Account Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .amount
                        }
                    
                    TextField("Starting Balance", text: $initialAmountString)
                        .keyboardType(.numbersAndPunctuation) // Changed to allow math symbols
                        .focused($focusedField, equals: .amount)
                        .onSubmit {
                            focusedField = .target
                        }
                }
                
                // SECTION 3: Target Amount
                Section(header: Text(targetSectionHeader), footer: Text(targetSectionFooter)) {
                    TextField(targetPlaceholder, text: $targetAmountString)
                        .keyboardType(.numbersAndPunctuation) // Changed to allow math symbols
                        .focused($focusedField, equals: .target)
                        .onSubmit {
                            if canSave {
                                saveAccount()
                            }
                        }
                }
                
                // SECTION 4: Payment/Contribution Plan (Optional)
                if shouldShowInstallmentSection {
                    Section(header: Text(installmentSectionHeader), footer: Text(installmentSectionFooter)) {
                        Toggle("Set \(isCredit ? "Payment" : "Contribution") Plan", isOn: $hasTargetDate)
                        
                        if hasTargetDate {
                            DatePicker("Target Date",
                                     selection: $targetDate,
                                     in: Date()...,
                                     displayedComponents: .date)
                            
                            Picker("Frequency", selection: $paymentFrequency) {
                                ForEach(PaymentFrequency.allCases) { frequency in
                                    Text(frequency.rawValue).tag(frequency)
                                }
                            }
                            
                            // Preview calculation
                            if let preview = calculatePreview() {
                                VStack(alignment: .leading, spacing: 8) {
                                    Divider()
                                    
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.blue)
                                        Text("Payment Preview")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    HStack {
                                        Text("Payments:")
                                        Spacer()
                                        Text("\(preview.periods)")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)
                                    
                                    HStack {
                                        Text("Amount per \(paymentFrequency.rawValue.lowercased()):")
                                        Spacer()
                                        Text(preview.amountPerPeriod.formattedCurrency(symbol: currencySymbol))
                                            .foregroundColor(isCredit ? .orange : .blue)
                                            .fontWeight(.semibold)
                                    }
                                    .font(.caption)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // SECTION 5: Account Groups (Optional)
                if !accountStore.accountGroups.isEmpty {
                    Section(header: Text("Add to Account Groups (Optional)"), footer: Text("This account will be included in the selected groups.")) {
                        ForEach(accountStore.accountGroups) { group in
                            Button {
                                toggleGroupSelection(group.id)
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.blue)
                                    Text(group.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedGroupIDs.contains(group.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // SECTION 6: Account Type Summary
                Section {
                    HStack {
                        Image(systemName: accountTypeIcon)
                            .foregroundColor(accountTypeColor)
                        Text("This will be a \(accountTypeName)")
                            .foregroundColor(accountTypeColor)
                    }
                }
            }
            .formToolbar(
                title: "New Account",
                canSave: canSave,
                onSave: {
                    saveAccount()
                },
                onCancel: {
                    dismiss()
                }
            )
            .mathPadToolbar(for: activeMathBinding)
            .onAppear {
                focusedField = .name
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var accountTypeFooter: String {
        if isCredit {
            return "Debt/Credit accounts track money you owe (credit cards, loans, installments)."
        } else {
            return "Cash accounts track money you have (bank accounts, wallets, savings)."
        }
    }
    
    private var startingBalanceFooter: String {
        if isCredit {
            return "Enter how much you currently owe (e.g., $1,250 of credit card debt)."
        } else {
            return "Enter how much money is currently in this account."
        }
    }
    
    private var targetSectionHeader: String {
        if isCredit {
            return "Spending Limit / Payoff Goal"
        } else {
            return "Savings Goal (Optional)"
        }
    }
    
    private var targetSectionFooter: String {
        let target = MathParser.calculate(targetAmountString)
        
        if isCredit {
            if target > 0 {
                return "This will be a Budget account. Track spending against this limit."
            } else {
                return "This will be a Debt account. Leave at $0 to track debt payoff, or set a monthly spending limit."
            }
        } else {
            if target > 0 {
                return "This will be a Goal account. Track your savings progress toward this target."
            } else {
                return "Leave blank for simple balance tracking."
            }
        }
    }
    
    private var targetPlaceholder: String {
        isCredit ? "0 (Debt) or Monthly Budget" : "Target Amount"
    }
    
    private var shouldShowInstallmentSection: Bool {
        let target = MathParser.calculate(targetAmountString)
        
        if isCredit {
            // Show for debt accounts (target = 0) or budgets (target > 0)
            return true
        } else {
            // Show for goals (target > 0)
            return target > 0
        }
    }
    
    private var installmentSectionHeader: String {
        isCredit ? "Payment Plan (Optional)" : "Contribution Plan (Optional)"
    }
    
    private var installmentSectionFooter: String {
        if isCredit {
            return "Set a target date to calculate required monthly payments to pay off this debt or stay within budget."
        } else {
            return "Set a target date to calculate required contributions to reach your savings goal."
        }
    }
    
    private var accountTypeIcon: String {
        let target = MathParser.calculate(targetAmountString)
        
        switch (isCredit, target > 0) {
        case (false, false): return "dollarsign.circle.fill"
        case (false, true):  return "target"
        case (true, true):   return "chart.bar.doc.horizontal.fill"
        case (true, false):  return "creditcard.and.123"
        }
    }
    
    private var accountTypeColor: Color {
        let target = MathParser.calculate(targetAmountString)
        
        switch (isCredit, target > 0) {
        case (false, false): return .primary
        case (false, true):  return .blue
        case (true, true):   return .purple
        case (true, false):  return .orange
        }
    }
    
    private var accountTypeName: String {
        let target = MathParser.calculate(targetAmountString)
        
        switch (isCredit, target > 0) {
        case (false, false): return "Debit Account"
        case (false, true):  return "Goal Account"
        case (true, true):   return "Budget Account"
        case (true, false):  return "Debt Account"
        }
    }
    
    // MARK: - Validation
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Calculations
    
    private func calculatePreview() -> (periods: Int, amountPerPeriod: Decimal)? {
        guard hasTargetDate else { return nil }
        
        let initial = MathParser.calculate(initialAmountString)
        let target = MathParser.calculate(targetAmountString)
        
        let today = Date()
        guard targetDate > today else { return nil }
        
        let periods = paymentFrequency.periodsBetween(from: today, to: targetDate)
        guard periods > 0 else { return nil }
        
        let remaining: Decimal
        
        if isCredit {
            if target > 0 {
                // Budget account: No installment calculation needed
                return nil
            } else {
                // Debt account: Calculate payoff amount
                remaining = max(initial, 0)
            }
        } else {
            // Goal account: Calculate savings needed
            remaining = max(target - initial, 0)
        }
        
        let amountPerPeriod = remaining / Decimal(periods)
        return (periods, amountPerPeriod)
    }
    
    // MARK: - Actions
    
    private func toggleGroupSelection(_ groupID: UUID) {
        if selectedGroupIDs.contains(groupID) {
            selectedGroupIDs.remove(groupID)
        } else {
            selectedGroupIDs.insert(groupID)
        }
    }
    
    private func saveAccount() {
        let amount = MathParser.calculate(initialAmountString)
        let targetRaw = MathParser.calculate(targetAmountString)
        
        // Logic for Target:
        // If Debt (isCredit=true): target can be 0 (payoff goal) or >0 (budget limit).
        // If Debit (isCredit=false): target must be >0 to be a Goal. If 0, it's nil.
        
        let target: Decimal?
        if isCredit {
            // For credit, we store whatever the user entered (0 or higher) if the string wasn't empty
            if targetAmountString.isEmpty {
                target = nil
            } else {
                target = targetRaw
            }
        } else {
            // For debit, 0 means "Standard Debit Account", so we convert to nil
            target = targetRaw > 0 ? targetRaw : nil
        }
        
        let newAccount = Account(
            name: name,
            initialAmount: amount,
            isCredit: isCredit,
            targetAmount: target,
            targetDate: hasTargetDate ? targetDate : nil,
            paymentFrequency: hasTargetDate ? paymentFrequency : nil
        )
        
        accountStore.accounts.append(newAccount)
        
        // Add to selected groups
        for groupID in selectedGroupIDs {
            if let index = accountStore.accountGroups.firstIndex(where: { $0.id == groupID }) {
                accountStore.accountGroups[index].memberIDs.append(newAccount.id)
            }
        }
        
        accountStore.save()
        dismiss()
    }
    
    private var activeMathBinding: Binding<String> {
        Binding {
            switch focusedField {
            case .amount: return initialAmountString
            case .target: return targetAmountString
            default: return ""
            }
        } set: { newValue in
            switch focusedField {
            case .amount: initialAmountString = newValue
            case .target: targetAmountString = newValue
            default: break
            }
        }
    }
}
