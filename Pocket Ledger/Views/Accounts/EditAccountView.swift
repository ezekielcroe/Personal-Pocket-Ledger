import SwiftUI

struct EditAccountView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    var account: Account
    
    @State private var name: String
    @State private var initialAmountString: String
    @State private var targetAmountString: String
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var paymentFrequency: PaymentFrequency
    
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    // MARK: - Focus State
    enum Field: Hashable {
        case name
        case amount
        case target
    }
    
    @FocusState private var focusedField: Field?

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _initialAmountString = State(initialValue: String(format: "%.2f", account.initialAmount))
        
        // Initialize target
        if let target = account.targetAmount {
            // Show 0.00 if it's a debt account with explicit 0 target, or any positive target
            _targetAmountString = State(initialValue: String(format: "%.2f", target))
        } else {
            // Nil target means empty string
            _targetAmountString = State(initialValue: "")
        }
        
        // Initialize target date and frequency
        _hasTargetDate = State(initialValue: account.targetDate != nil)
        _targetDate = State(initialValue: account.targetDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
        _paymentFrequency = State(initialValue: account.paymentFrequency ?? .monthly)
    }

    var body: some View {
        NavigationStack {
            Form {
                // SECTION 1: Account Type (Read-Only)
                Section(footer: Text("Account type cannot be changed after creation. Create a new account if you need a different type.")) {
                    HStack {
                        Image(systemName: account.accountType.icon)
                            .foregroundColor(accountTypeColor)
                        Text(account.accountType.rawValue + " Account")
                            .foregroundColor(accountTypeColor)
                        Spacer()
                    }
                }
                
                // SECTION 2: Account Details
                Section(header: Text("Account Details")) {
                    TextField("Name", text: $name)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            focusedField = .amount
                        }
                    
                    HStack {
                        Text("Starting Balance")
                        Spacer()
                        TextField("0.00", text: $initialAmountString)
                            .keyboardType(.numbersAndPunctuation) // Changed for math support
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .amount)
                            .onSubmit {
                                focusedField = .target
                            }
                    }
                }
                
                // SECTION 3: Target Amount
                Section(header: Text(targetSectionHeader), footer: Text(targetSectionFooter)) {
                    HStack {
                        Text("Target")
                        Spacer()
                        TextField(targetPlaceholder, text: $targetAmountString)
                            .keyboardType(.numbersAndPunctuation) // Changed for math support
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .target)
                            .onSubmit {
                                saveChanges()
                            }
                    }
                }
                
                // SECTION 4: Payment/Contribution Plan
                if shouldShowInstallmentSection {
                    Section(header: Text(installmentSectionHeader), footer: Text(installmentSectionFooter)) {
                        Toggle("Set \(account.isCredit ? "Payment" : "Contribution") Plan", isOn: $hasTargetDate)
                        
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
                                        Text("Updated Plan")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    HStack {
                                        Text("Payments Remaining:")
                                        Spacer()
                                        Text("\(preview.periods)")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)
                                    
                                    HStack {
                                        Text("Amount per \(paymentFrequency.rawValue.lowercased()):")
                                        Spacer()
                                        Text(preview.amountPerPeriod.formattedCurrency(symbol: currencySymbol))
                                            .foregroundColor(account.isCredit ? .orange : .blue)
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
                
                // SECTION 5: Current Status
                Section(header: Text("Current Status"), footer: Text("Current balance is calculated from your starting balance plus all transactions.")) {
                    HStack {
                        Text("Current Balance")
                        Spacer()
                        Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                            .foregroundColor(currentBalanceColor)
                    }
                    
                    // Progress indicator
                    if let target = Double(targetAmountString), target > 0 {
                        HStack {
                            Text("Progress")
                            Spacer()
                            Text(progressText)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .formToolbar(
                title: "Edit Account",
                canSave: canSave,
                onSave: {
                    saveChanges()
                },
                onCancel: {
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var accountTypeColor: Color {
        switch account.accountType {
        case .debit:  return .primary
        case .goal:   return .blue
        case .budget: return .purple
        case .debt:   return .orange
        }
    }
    
    private var targetSectionHeader: String {
        switch account.accountType {
        case .debit:  return "Savings Goal (Optional)"
        case .goal:   return "Savings Goal"
        case .budget: return "Monthly Budget Limit"
        case .debt:   return "Payoff Goal"
        }
    }
    
    private var targetSectionFooter: String {
        switch account.accountType {
        case .debit:
            return "Add a target to convert this into a Goal account for tracking savings progress."
        case .goal:
            return "Your savings target. Progress is tracked automatically."
        case .budget:
            return "Your monthly spending limit. You'll see warnings when approaching this amount."
        case .debt:
            return "Set to $0 to track debt payoff progress. Set higher to create a monthly spending budget."
        }
    }
    
    private var targetPlaceholder: String {
        switch account.accountType {
        case .debit, .goal: return "Target Amount"
        case .budget:       return "Monthly Limit"
        case .debt:         return "0"
        }
    }
    
    private var shouldShowInstallmentSection: Bool {
        switch account.accountType {
        case .goal, .debt:
            return true
        case .budget:
            return false // Budgets don't use installment plans (they're monthly)
        case .debit:
            let target = MathParser.calculate(targetAmountString)
            return target > 0 // Only show if user adds a target
        }
    }
    
    private var installmentSectionHeader: String {
        account.isCredit ? "Payment Plan (Optional)" : "Contribution Plan (Optional)"
    }
    
    private var installmentSectionFooter: String {
        switch account.accountType {
        case .goal:
            return "Set a target date to calculate how much you need to save each period to reach your goal."
        case .debt:
            return "Set a target date to calculate required payments to pay off this debt."
        default:
            return ""
        }
    }
    
    private var currentBalanceColor: Color {
        let balance = data.balance(for: account)
        
        switch account.accountType {
        case .debit:
            return balance < 0 ? .red : .primary
        case .goal:
            if let target = Double(targetAmountString), balance >= target {
                return .green
            }
            return .primary
        case .budget:
            if let target = Double(targetAmountString), balance > target {
                return .red
            }
            return .primary
        case .debt:
            return balance > 0 ? .orange : .green
        }
    }
    
    private var progressText: String {
        let target = MathParser.calculate(targetAmountString)
        guard target > 0 else { return "" }
        
        let current = data.balance(for: account)
        let percentage = (current / target) * 100
        
        switch account.accountType {
        case .goal:
            if current >= target {
                return "Goal reached! 🎉"
            } else {
                return String(format: "%.0f%% of goal reached", percentage)
            }
        case .budget:
            return String(format: "%.0f%% of budget used", percentage)
        case .debt:
            return String(format: "%.0f%% of debt remaining", percentage)
        default:
            return ""
        }
    }
    
    // MARK: - Validation
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Calculations
    
    private func calculatePreview() -> (periods: Int, amountPerPeriod: Double)? {
        guard hasTargetDate else { return nil }
        
        let current = data.balance(for: account)
        let target = MathParser.calculate(targetAmountString)
        
        let today = Date()
        guard targetDate > today else { return nil }
        
        let periods = paymentFrequency.periodsBetween(from: today, to: targetDate)
        guard periods > 0 else { return nil }
        
        let remaining: Double
        
        switch account.accountType {
        case .goal:
            // Calculate savings needed
            remaining = max(target - current, 0)
        case .debt:
            // Calculate payoff amount
            remaining = max(current, 0)
        default:
            return nil
        }
        
        let amountPerPeriod = remaining / Double(periods)
        return (periods, amountPerPeriod)
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        let amount = MathParser.calculate(initialAmountString)
        let targetRaw = MathParser.calculate(targetAmountString)
        
        // Parse target: empty string or "0" → nil for debt accounts
        let target: Double?
        if isTargetEmptyOrZero(targetAmountString, val: targetRaw) {
            target = nil
        } else {
            target = targetRaw
        }
        
        data.updateAccount(
            id: account.id,
            name: name,
            initialAmount: amount,
            targetAmount: target,
            targetDate: hasTargetDate ? targetDate : nil,
            paymentFrequency: hasTargetDate ? paymentFrequency : nil
        )
        dismiss()
    }
    
    /// Helper to determine if we should treat the target as nil
    private func isTargetEmptyOrZero(_ str: String, val: Double) -> Bool {
        if str.isEmpty { return true }
        if !account.isCredit && val == 0 { return true } // Debit/Goal: 0 target = nil
        // For Credit/Debt: explicit 0 is a valid target (payoff goal), so we keep it unless empty
        return false
    }
}
