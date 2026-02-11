import SwiftUI

/// Displays all transactions tagged with a specific tag, optionally filtered by a date range.
struct TagDetailView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    var tag: Tag
    // NEW: Optional filter passed from Insights
    var dateFilter: DateInterval? = nil

    var body: some View {
        List {
            // NEW: Summary Card if filtered
            if let interval = dateFilter {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total for Period")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(totalAmount.formattedCurrency(symbol: currencySymbol))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(formatInterval(interval))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Transactions")) {
                if filteredTransactions.isEmpty {
                    Text("No transactions found for this period.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredTransactions) { transaction in
                        // Assuming you have TransactionDetailView available
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
        }
        .navigationTitle("#\(tag.name)")
    }
    
    // MARK: - Helpers
    
    private var filteredTransactions: [Transaction] {
        let all = transactionStore.transactions(for: tag)
        guard let interval = dateFilter else {
            return all.sorted { $0.date > $1.date }
        }
        return all
            .filter { interval.contains($0.date) }
            .sorted { $0.date > $1.date }
    }
    
    private var totalAmount: Decimal {
        filteredTransactions.reduce(0) { $0 + $1.amount }
    }
    
    private func formatInterval(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: interval.start)) - \(formatter.string(from: interval.end))"
    }
}
