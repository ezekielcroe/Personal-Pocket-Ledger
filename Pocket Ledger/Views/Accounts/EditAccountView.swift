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
                Section(header: Text("Account Details")) {
                    // 1. Name Field
                    TextField("Name", text: $name)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            focusedField = .amount
                        }
                    
                    // 2. Initial Amount Field (Manual implementation for Focus control)
                    HStack {
                        Text(account.isCredit ? "Credit Limit" : "Initial Amount")
                        Spacer()
                        TextField("0.00", text: $initialAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .amount)
                            .onSubmit {
                                // Logic: If Debit, go to Target. If Credit, Save.
                                if !account.isCredit {
                                    focusedField = .target
                                } else {
                                    saveChanges()
                                }
                            }
                    }
                    
                    // 3. Target Field (Debit Only)
                    if !account.isCredit {
                        HStack {
                            Text("Goal Target")
                            Spacer()
                            TextField("Optional", text: $targetAmountString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .target)
                                .onSubmit {
                                    saveChanges()
                                }
                        }
                    }
                }
            }
            .formToolbar(
                title: "Edit Account",
                canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
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
    
    // MARK: - Logic
    
    private func saveChanges() {
        let amount = Double(initialAmountString) ?? 0.0
        let target = targetAmountString.isEmpty ? nil : Double(targetAmountString)
        
        data.updateAccount(
            id: account.id,
            name: name,
            initialAmount: amount,
            targetAmount: account.isCredit ? nil : target
        )
        dismiss()
    }
}
