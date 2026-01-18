import SwiftUI

/// Form to add a new account with a name, starting balance, and optional target.
struct AddAccountView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var initialAmountString: String = ""
    @State private var isCredit: Bool = false
    @State private var targetAmountString: String = ""
    
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
                // SECTION 1: Account Type Toggle (at top for clarity)
                Section(footer: Text(isCredit ?
                        "Credit accounts track debt or spending (credit cards, loans, budgets)." :
                        "Debit accounts track cash on hand (bank accounts, wallets, savings).")) {
                    Toggle("Credit Account", isOn: $isCredit)
                        .onChange(of: isCredit) { _ in
                            // Don't clear target - let user decide
                            // They might be switching back and forth
                        }
                }
                
                // SECTION 2: Name
                Section(header: Text("Account Name")) {
                    TextField("e.g., Checking, Visa, Emergency Fund", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .amount
                        }
                }
                
                // SECTION 3: Starting Balance
                Section(header: Text("Starting Balance"), footer: Text(isCredit ?
                        "Enter the current balance owed or spent (e.g., $1,250 of credit card debt)." :
                        "Enter how much money is currently in this account.")) {
                    TextField("Amount", text: $initialAmountString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .onSubmit {
                            focusedField = .target
                        }
                }
                
                // SECTION 4: Target Amount (Optional)
                Section(header: Text("Target Amount (Optional)"), footer: Text(targetFooterText)) {
                    TextField("Target", text: $targetAmountString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .target)
                        .onSubmit {
                            if canSave {
                                saveAccount()
                            }
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
            .decimalPadToolbar()
            .onAppear {
                focusedField = .name
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Footer text that explains what the target means for each account type
    private var targetFooterText: String {
        let hasTarget = !targetAmountString.isEmpty
        
        if !hasTarget {
            return "Leave blank for simple balance tracking."
        }
        
        if isCredit {
            return "This will become a Budget account. Track spending against a limit (e.g., $500/month for groceries)."
        } else {
            return "This will become a Goal account. Track progress toward a savings target (e.g., $5,000 emergency fund)."
        }
    }
    
    // MARK: - Validation
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Actions
    
    private func saveAccount() {
        let amount = Double(initialAmountString) ?? 0
        let target = targetAmountString.isEmpty ? nil : Double(targetAmountString)
        
        data.addAccount(
            name: name,
            initialAmount: amount,
            isCredit: isCredit,
            targetAmount: target
        )
        dismiss()
    }
}
