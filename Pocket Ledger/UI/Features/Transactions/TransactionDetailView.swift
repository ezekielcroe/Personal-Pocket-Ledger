import SwiftUI

struct TransactionDetailView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    var transaction: Transaction

    var body: some View {
        List {
            // Header Section: Amount and Date
            Section {
                VStack(alignment: .center, spacing: 8) {
                    // Badge
                    Text(displayType)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(displayColor.opacity(0.1))
                        .foregroundColor(displayColor)
                        .cornerRadius(8)
                    
                    // Amount (NEW: Formatted)
                    Text(transaction.amount.formattedCurrency(symbol: currencySymbol))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(transaction.date.formatted(date: .long, time: .shortened))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .listRowBackground(Color.clear)

            // Core Details
            Section(header: Text("Details")) {
                DetailRow(label: "Account", value: accountName)
                DetailRow(label: "Category", value: categoryName)
                
                if !transaction.remark.isEmpty {
                    DetailRow(label: "Remark", value: transaction.remark)
                }
                
                if transaction.isOutlier {
                    HStack {
                        Text("Outlier")
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Metadata
            Section(header: Text("Metadata")) {
                DetailRow(label: "ID", value: transaction.id.uuidString)
                        .font(.caption)
                        .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers
    
    private var accountName: String {
        accountStore.accounts.first(where: { $0.id == transaction.accountID })?.name ?? "Unknown"
    }
    
    private var categoryName: String {
        transactionStore.categories.first(where: { $0.id == transaction.categoryID })?.name ?? "Unknown"
    }
    
    // Display Logic for Transfers
    private var isTransfer: Bool { transaction.linkedTransactionID != nil }
    
    private var displayType: String {
        if isTransfer { return "Transfer" }
        return transaction.type == .inflow ? "Inflow" : "Outflow"
    }
    
    private var displayColor: Color {
        if isTransfer { return .blue }
        return transaction.type == .inflow ? .green : .red
    }
}

/// A simple helper row for key-value pairs
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
