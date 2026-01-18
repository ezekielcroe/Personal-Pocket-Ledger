import SwiftUI

/// Form to add a new account with a name and initial balance.
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
                // Section 1: Name
                Section(header: Text("Name")) {
                    TextField("Account Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next) // Explicit "Next" button on keyboard
                        .onSubmit {
                            // Name -> Amount
                            focusedField = .amount
                        }
                }
                
                // Section 2: Amount
                Section(header: Text(isCredit ? "Credit Limit" : "Initial Amount")) {
                    TextField(isCredit ? "Credit Limit" : "Amount", text: $initialAmountString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .onSubmit {
                            // Amount -> Target (if Debit) OR Save (if Credit)
                            if !isCredit {
                                focusedField = .target
                            } else if canSave {
                                saveAccount()
                            }
                        }
                }
                
                // Section 3: Target (Debit Only)
                if !isCredit {
                    Section(header: Text("Goal Target (Optional)")) {
                        TextField("Target Amount", text: $targetAmountString)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .target)
                            .onSubmit {
                                // Target -> Save
                                if canSave {
                                    saveAccount()
                                }
                            }
                    }
                }

                // Section 4: Type Toggle
                Section {
                    Toggle("Credit Account", isOn: $isCredit)
                        .onChange(of: isCredit) { newValue in
                            // Clear target if switching to Credit, as Credit accounts don't have savings goals
                            if newValue {
                                targetAmountString = ""
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
                // Auto-focus on Name field when view appears
                focusedField = .name
            }
        }
    }
    
    // MARK: - Helpers
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveAccount() {
        let amount = Double(initialAmountString) ?? 0
        
        // Parse target if present (and only if not credit)
        let target = (!isCredit && !targetAmountString.isEmpty) ? Double(targetAmountString) : nil
        
        data.addAccount(
            name: name,
            initialAmount: amount,
            isCredit: isCredit,
            targetAmount: target
        )
        dismiss()
    }
}
