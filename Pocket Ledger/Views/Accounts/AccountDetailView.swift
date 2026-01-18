import SwiftUI

/// Displays details about an account including its transactions and statistics.
struct AccountDetailView: View {
    @EnvironmentObject var data: AppData
    var account: Account

    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    // Fetches the global fiscal preference
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    var body: some View {
        List {
            // MARK: - Balance
            Section(header: Text("Balance")) {
                HStack {
                    Text("Current Balance")
                    Spacer()
                    Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                        .foregroundColor(data.balance(for: account) >= 0 ? .primary : .red)
                }
            }
            
            // MARK: - Statistics
            Section(header: Text("Statistics"), footer: fiscalRangeFooter) {
                let monthlyTotals = calculateCurrentMonthTotals()
                let stats = data.stats(for: account)
                
                StatRow(title: "Inflow (This Month)", value: monthlyTotals.inflow, symbol: currencySymbol, color: .green)
                StatRow(title: "Outflow (This Month)", value: monthlyTotals.outflow, symbol: currencySymbol, color: .red)
                
                StatRow(title: "Avg Inflow / Month", value: stats.monthlyInflow, symbol: currencySymbol)
                StatRow(title: "Avg Outflow / Month", value: stats.monthlyOutflow, symbol: currencySymbol)
            }
            
            // MARK: - Recent Transactions
            Section(header: Text("Recent Transactions (Last 20)")) {
                let recentTransactions = data.transactions(for: account)
                    .sorted { $0.date > $1.date }
                    .prefix(20)
                
                if recentTransactions.isEmpty {
                    Text("No transactions yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(recentTransactions) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
        }
        .navigationTitle(account.name)
    }
    
    // MARK: - View Helpers
    
    /// Provides a footer explaining the active fiscal period when an offset is used.
    @ViewBuilder
    private var fiscalRangeFooter: some View {
        if fiscalStartDay != 1 {
            let range = getCurrentFiscalRange()
            let rangeText = formatFiscalRange(range)
            Text("Current period: \(rangeText)")
        } else {
            EmptyView()
        }
    }

    /// Safely formats the date range for display without using assignments in the ViewBuilder.
    private func formatFiscalRange(_ range: (start: Date, end: Date)) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }
    
    // MARK: - Logic Helpers
    
    /// Aggregates totals for the current period based on the fiscal start day.
    private func calculateCurrentMonthTotals() -> (inflow: Double, outflow: Double) {
        let range = getCurrentFiscalRange()
        let accountTransactions = data.transactions(for: account)
        
        let thisMonthTransactions = accountTransactions.filter {
            $0.date >= range.start && $0.date <= range.end
        }
        
        let inflow = thisMonthTransactions
            .filter { $0.type == .inflow }
            .reduce(0) { $0 + $1.amount }
            
        let outflow = thisMonthTransactions
            .filter { $0.type == .outflow }
            .reduce(0) { $0 + $1.amount }
            
        return (inflow, outflow)
    }

    /// Computes the start and end dates for the month containing the current date.
    private func getCurrentFiscalRange() -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: now)
        
        var startComponents = DateComponents()
        startComponents.year = components.year
        startComponents.month = components.month
        startComponents.day = fiscalStartDay
        
        var start = calendar.date(from: startComponents) ?? now
        
        // Adjusts to the previous month if the current date is before the fiscal start day.
        if now < start {
            start = calendar.date(byAdding: .month, value: -1, to: start) ?? start
        }
        
        let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? now
        return (start, end)
    }
}

// MARK: - Helper View

/// A consistent row format for displaying labeled monetary values.
struct StatRow: View {
    let title: String
    let value: Double
    let symbol: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.formattedCurrency(symbol: symbol))
                .foregroundColor(color)
        }
    }
}
