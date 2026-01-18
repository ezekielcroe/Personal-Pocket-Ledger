import SwiftUI

struct EditAccountView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    var account: Account
    
    @State private var name: String
    @State private var initialAmountString: String
    @State private var targetAmountString: String
    
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
        
        // Initialize target string
        if let target = account.targetAmount {
            _targetAmountString = State(initialValue: String(format: "%.2f", target))
        } else {
            _targetAmountString = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // SECTION 1: Account Type (Read-Only)
                Section(footer: Text("Account type cannot be changed after creation. Create a new account if you need a different type.")) {
                    HStack {
                        Text("Account Type")
                        Spacer()
                        Text(accountTypeLabel)
                            .foregroundColor(.secondary)
                    }
                }
                
                // SECTION 2: Account Details
                Section(header: Text("Account Details")) {
                    // Name Field
                    TextField("Name", text: $name)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            focusedField = .amount
                        }
                    
                    // Starting Balance Field
                    HStack {
                        Text("Starting Balance")
                        Spacer()
                        TextField("0.00", text: $initialAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .amount)
                            .onSubmit {
                                focusedField = .target
                            }
                    }
                }
                
                // SECTION 3: Target Amount
                Section(header: Text("Target Amount (Optional)"), footer: Text(targetFooterText)) {
                    HStack {
                        Text("Target")
                        Spacer()
                        TextField("None", text: $targetAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .target)
                            .onSubmit {
                                saveChanges()
                            }
                    }
                }
                
                // SECTION 4: Current Balance (Read-Only Info)
                Section(header: Text("Current Status"), footer: Text("Current balance is calculated from your starting balance plus all transactions.")) {
                    HStack {
                        Text("Current Balance")
                        Spacer()
                        Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                            .foregroundColor(currentBalanceColor)
                    }
                    
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
            .decimalPadToolbar()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Human-readable account type label
    private var accountTypeLabel: String {
        switch (account.isCredit, account.targetAmount) {
        case (false, nil):   return "Debit Account"
        case (true, nil):    return "Credit Account"
        case (false, .some): return "Goal Account"
        case (true, .some):  return "Budget Account"
        }
    }
    
    /// Footer text explaining what the target means for this account
    private var targetFooterText: String {
        let hasTarget = !targetAmountString.isEmpty
        
        if !hasTarget {
            if account.isCredit {
                return "Add a target to track this as a Budget account with spending limits."
            } else {
                return "Add a target to track this as a Goal account with savings targets."
            }
        }
        
        if account.isCredit {
            return "Budget target: You'll see warnings when spending approaches this limit."
        } else {
            return "Savings goal: Track your progress toward reaching this amount."
        }
    }
    
    /// Color for current balance display
    private var currentBalanceColor: Color {
        let balance = data.balance(for: account)
        
        if account.isCredit {
            // Credit: High balance = more debt/spending
            if balance > account.initialAmount * 0.9 {
                return .red
            } else if balance > account.initialAmount * 0.7 {
                return .orange
            }
        } else {
            // Debit: Negative = overdrawn
            if balance < 0 {
                return .red
            }
        }
        return .primary
    }
    
    /// Progress text for goal/budget tracking
    private var progressText: String {
        guard let target = Double(targetAmountString), target > 0 else {
            return ""
        }
        
        let current = data.balance(for: account)
        let percentage = (current / target) * 100
        
        if account.isCredit {
            // Budget: Show how much of limit is used
            return String(format: "%.0f%% of budget used", percentage)
        } else {
            // Goal: Show progress toward target
            if current >= target {
                return "Goal reached! 🎉"
            } else {
                return String(format: "%.0f%% of goal reached", percentage)
            }
        }
    }
    
    // MARK: - Validation
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        let amount = Double(initialAmountString) ?? 0.0
        let target = targetAmountString.isEmpty ? nil : Double(targetAmountString)
        
        data.updateAccount(
            id: account.id,
            name: name,
            initialAmount: amount,
            targetAmount: target
        )
        dismiss()
    }
}
