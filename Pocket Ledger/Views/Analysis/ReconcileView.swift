//
//  ReconcileView.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 17/1/26.
//

import SwiftUI

struct ReconcileView: View {
    @EnvironmentObject var data: AppData
    @Environment(\.dismiss) var dismiss
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    // Tracks the user's manual input for each account
    @State private var actualBalanceInputs: [UUID: String] = [:]
    
    // State for the confirmation alert
    @State private var accountToAdjust: Account?
    @State private var difference: Double = 0
    @State private var showingAdjustmentAlert = false
    
    // MARK: - Focus State
    @FocusState private var focusedAccountID: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Enter the actual real-world balance for your accounts. Pocket Ledger will create a transaction to correct any differences.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ForEach(Array(data.accounts.enumerated()), id: \.element.id) { index, account in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(account.name)
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("System Balance")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", data.balance(for: account)))
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Actual Balance")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                TextField("0.00", text: Binding(
                                    get: { actualBalanceInputs[account.id] ?? "" },
                                    set: { actualBalanceInputs[account.id] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .focused($focusedAccountID, equals: account.id)
                                .onSubmit {
                                    handleAccountSubmit(currentIndex: index)
                                }
                            }
                        }
                        
                        if let diff = calculateDifference(for: account), abs(diff) > 0.01 {
                            HStack {
                                Text("Difference: \(String(format: "%.2f", diff))")
                                    .font(.caption)
                                    .foregroundColor(diff > 0 ? .green : .red)
                                Spacer()
                                Button("Fix") {
                                    accountToAdjust = account
                                    difference = diff
                                    showingAdjustmentAlert = true
                                }
                                .buttonStyle(.borderedProminent)
                                .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Reconcile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if hasPendingDifferences {
                        Button("Fix All") {
                            fixAllDifferences()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .alert("Create Adjustment?", isPresented: $showingAdjustmentAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Create Transaction") {
                    createAdjustment()
                }
            } message: {
                if let account = accountToAdjust {
                    Text("This will create a \(difference > 0 ? "Inflow" : "Outflow") of \(String(format: "%.2f", abs(difference))) for \(account.name) to match your records.")
                }
            }
            .decimalPadToolbar()
            .onAppear {
                // Auto-focus on first account when view appears
                if let firstAccount = data.accounts.first {
                    focusedAccountID = firstAccount.id
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func calculateDifference(for account: Account) -> Double? {
        guard let input = actualBalanceInputs[account.id], let actual = Double(input) else { return nil }
        let system = data.balance(for: account)
        return actual - system
    }
    
    private var hasPendingDifferences: Bool {
        data.accounts.contains { account in
            if let diff = calculateDifference(for: account), abs(diff) > 0.01 {
                return true
            }
            return false
        }
    }
    
    // MARK: - Focus Chain Logic
    
    /// Called when user taps Return on an account's balance field
    private func handleAccountSubmit(currentIndex: Int) {
        let nextIndex = currentIndex + 1
        
        // If there's a next account, focus on it
        if nextIndex < data.accounts.count {
            let nextAccount = data.accounts[nextIndex]
            focusedAccountID = nextAccount.id
        } else {
            // Last account - dismiss keyboard
            focusedAccountID = nil
            
            // If there are differences, optionally show Fix All prompt
            if hasPendingDifferences {
                // User can manually tap "Fix All" button in toolbar
            }
        }
    }
    
    // MARK: - Adjustment Logic
    
    private func fixAllDifferences() {
        for account in data.accounts {
            if let diff = calculateDifference(for: account), abs(diff) > 0.01 {
                createAdjustmentFor(account: account, difference: diff)
            }
        }
        
        // Clear all inputs after batch fix
        actualBalanceInputs.removeAll()
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func createAdjustment() {
        guard let account = accountToAdjust else { return }
        createAdjustmentFor(account: account, difference: difference)
        
        // Clear input after fix
        actualBalanceInputs[account.id] = nil
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func createAdjustmentFor(account: Account, difference: Double) {
        let type: TransactionType = difference > 0 ? .inflow : .outflow
        let amount = abs(difference)
        
        // 1. Get all valid categories for this transaction type
        let validCategories = data.categories.filter { $0.type.rawValue == type.rawValue }
        
        // 2. Try to find a preferred category ("Other" or "Adjustment")
        var targetCategory = validCategories.first { $0.name == "Other" }
        if targetCategory == nil {
            targetCategory = validCategories.first { $0.name == "Adjustment" }
        }
        
        // 3. Fallback to the first available category if no preferred one exists
        if targetCategory == nil {
            targetCategory = validCategories.first
        }
        
        if let category = targetCategory {
            data.addTransaction(
                type: type,
                accountID: account.id,
                categoryID: category.id,
                tagIDs: [],
                amount: amount,
                date: Date(),
                isOutlier: false
            )
        }
    }
}
