import SwiftUI

struct CategoryDetailView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    let category: Category
    // UPDATED: Now accepts a full range (e.g., "Last Year") instead of just one month
    let dateFilter: DateInterval
    
    var body: some View {
        List {
            // Header: Total for this period
            Section {
                VStack(alignment: .center, spacing: 8) {
                    Text(category.emoji)
                        .font(.system(size: 50))
                    
                    Text(category.name)
                        .font(.headline)
                    
                    Text(totalAmount.formattedCurrency(symbol: currencySymbol))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(category.type == .inflow ? .green : .red)
                    
                    // Display the range cleanly
                    Text(formattedDateRange)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }
            
            // Transaction List
            Section(header: Text("Transactions")) {
                if transactions.isEmpty {
                    Text("No transactions found in this period.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(transactions) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Logic
    
    private var transactions: [Transaction] {
        return transactionStore.transactions
            .filter { $0.categoryID == category.id }
            .filter { dateFilter.contains($0.date) }
            .sorted { $0.date > $1.date }
    }
    
    private var totalAmount: Decimal {
        transactions.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    // Smart formatter to handle "Month" vs "Range"
    private var formattedDateRange: String {
        let calendar = Calendar.current
        let start = dateFilter.start
        let end = dateFilter.end
        
        // Check if it looks like a full month (e.g., Jan 1 to Feb 1)
        if let monthEnd = calendar.date(byAdding: .month, value: 1, to: start),
           calendar.isDate(monthEnd, equalTo: end, toGranularity: .day) &&
           calendar.component(.day, from: start) == 1 {
            return start.formatted(.dateTime.month(.wide).year())
        }
        
        // Otherwise, show range (e.g., "Jan 15 - Feb 14")
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: start)) - \(formatter.string(from: end.addingTimeInterval(-1)))"
    }
}
