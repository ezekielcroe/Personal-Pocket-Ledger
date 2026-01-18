import SwiftUI

struct CategoryDetailView: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    
    let category: Category
    let monthContext: Date // The month selected in Insights
    
    var body: some View {
        List {
            // Header: Total for this month
            Section {
                VStack(alignment: .center, spacing: 8) {
                    Text(category.emoji)
                        .font(.system(size: 50))
                    
                    Text(category.name)
                        .font(.headline)
                    
                    Text(totalAmount.formattedCurrency(symbol: currencySymbol))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(category.type == .inflow ? .green : .red)
                    
                    Text(monthString)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }
            
            // Transaction List
            Section(header: Text("Transactions")) {
                if transactions.isEmpty {
                    Text("No transactions found.")
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
        let calendar = Calendar.current
        return data.transactions
            .filter { $0.categoryID == category.id }
            .filter { calendar.isDate($0.date, equalTo: monthContext, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }
    
    private var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthContext)
    }
}
