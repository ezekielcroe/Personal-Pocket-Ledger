import SwiftUI

/// Displays details about an account including its transactions and statistics.
struct AccountDetailView: View {
    @EnvironmentObject var data: AppData
    var account: Account

    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    var body: some View {
        List {
            // SECTION 1: Balance Card (Type-Specific)
            balanceSection
            
            // SECTION 2: Target Progress (Goals & Budgets Only)
            if account.targetAmount != nil {
                targetProgressSection
            }
            
            // SECTION 3: Statistics
            statisticsSection
            
            // SECTION 4: Recent Transactions
            recentTransactionsSection
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Balance Section (Type-Specific)
    
    @ViewBuilder
    private var balanceSection: some View {
        Section {
            VStack(spacing: 12) {
                // Account Type Badge
                HStack {
                    Image(systemName: accountTypeIcon)
                        .foregroundColor(accountTypeColor)
                    Text(accountTypeLabel)
                        .font(.subheadline)
                        .foregroundColor(accountTypeColor)
                    Spacer()
                }
                
                // Current Balance
                VStack(alignment: .leading, spacing: 4) {
                    Text(balanceLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(balanceColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Context-specific subtitle
                if let subtitle = balanceSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Target Progress Section (Goals & Budgets)
    
    @ViewBuilder
    private var targetProgressSection: some View {
        if let target = account.targetAmount {
            Section(header: Text(account.isCredit ? "Budget Progress" : "Goal Progress")) {
                VStack(spacing: 16) {
                    // Progress Bar
                    progressBar(current: data.balance(for: account), target: target)
                    
                    // Progress Stats
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.isCredit ? "Spent" : "Saved")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(account.isCredit ? "Budget" : "Goal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(target.formattedCurrency(symbol: currencySymbol))
                                .font(.headline)
                        }
                    }
                    
                    // Remaining/Over amount
                    if account.isCredit {
                        // Budget: Show remaining or overspent
                        let remaining = target - data.balance(for: account)
                        HStack {
                            Image(systemName: remaining >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(remaining >= 0 ? .green : .red)
                            Text(remaining >= 0 ?
                                 "\(remaining.formattedCurrency(symbol: currencySymbol)) remaining" :
                                 "Over budget by \(abs(remaining).formattedCurrency(symbol: currencySymbol))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(remaining >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        // Goal: Show remaining or achieved
                        let current = data.balance(for: account)
                        if current >= target {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Goal reached! 🎉")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            let remaining = target - current
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                                Text("\(remaining.formattedCurrency(symbol: currencySymbol)) to go")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Statistics Section
    
    @ViewBuilder
    private var statisticsSection: some View {
        Section(header: Text("Statistics"), footer: fiscalRangeFooter) {
            let monthlyTotals = calculateCurrentMonthTotals()
            let stats = data.stats(for: account)
            
            // This Period Stats
            if account.isCredit {
                // Credit accounts: Show spending this period
                StatRow(title: "Spending (This Month)",
                       value: monthlyTotals.outflow,
                       symbol: currencySymbol,
                       color: .red)
                StatRow(title: "Payments (This Month)",
                       value: monthlyTotals.inflow,
                       symbol: currencySymbol,
                       color: .green)
            } else {
                // Debit accounts: Show income/expenses
                StatRow(title: "Income (This Month)",
                       value: monthlyTotals.inflow,
                       symbol: currencySymbol,
                       color: .green)
                StatRow(title: "Expenses (This Month)",
                       value: monthlyTotals.outflow,
                       symbol: currencySymbol,
                       color: .red)
            }
            
            Divider()
            
            // Average Stats
            if account.isCredit {
                StatRow(title: "Avg Spending / Month",
                       value: stats.monthlyOutflow,
                       symbol: currencySymbol)
                StatRow(title: "Avg Payments / Month",
                       value: stats.monthlyInflow,
                       symbol: currencySymbol)
            } else {
                StatRow(title: "Avg Income / Month",
                       value: stats.monthlyInflow,
                       symbol: currencySymbol)
                StatRow(title: "Avg Expenses / Month",
                       value: stats.monthlyOutflow,
                       symbol: currencySymbol)
            }
        }
    }
    
    // MARK: - Recent Transactions Section
    
    @ViewBuilder
    private var recentTransactionsSection: some View {
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
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func progressBar(current: Double, target: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 8)
                    .fill(progressBarColor(current: current, target: target))
                    .frame(width: progressBarWidth(current: current, target: target, totalWidth: geometry.size.width),
                           height: 12)
            }
        }
        .frame(height: 12)
    }
    
    // MARK: - Computed Properties
    
    private var accountTypeIcon: String {
        switch (account.isCredit, account.targetAmount) {
        case (false, nil):   return "dollarsign.circle.fill"
        case (true, nil):    return "creditcard.fill"
        case (false, .some): return "target"
        case (true, .some):  return "chart.bar.doc.horizontal.fill"
        }
    }
    
    private var accountTypeLabel: String {
        switch (account.isCredit, account.targetAmount) {
        case (false, nil):   return "Debit Account"
        case (true, nil):    return "Credit Account"
        case (false, .some): return "Goal Account"
        case (true, .some):  return "Budget Account"
        }
    }
    
    private var accountTypeColor: Color {
        switch (account.isCredit, account.targetAmount) {
        case (false, nil):   return .primary
        case (true, nil):    return .orange
        case (false, .some): return .blue
        case (true, .some):  return .purple
        }
    }
    
    private var balanceLabel: String {
        switch (account.isCredit, account.targetAmount) {
        case (false, nil):   return "Current Balance"
        case (true, nil):    return "Amount Owed"
        case (false, .some): return "Current Savings"
        case (true, .some):  return "Total Spent"
        }
    }
    
    private var balanceColor: Color {
        let balance = data.balance(for: account)
        
        if account.isCredit {
            // Credit: Warn if high spending/debt
            if let target = account.targetAmount {
                // Budget account: Warn if over budget
                return balance > target ? .red : .primary
            } else {
                // Credit card: Warn if high utilization
                if balance > account.initialAmount * 0.9 {
                    return .red
                } else if balance > account.initialAmount * 0.7 {
                    return .orange
                }
            }
        } else {
            // Debit: Warn if negative
            if balance < 0 {
                return .red
            } else if let target = account.targetAmount, balance >= target {
                return .green
            }
        }
        return .primary
    }
    
    private var balanceSubtitle: String? {
        if account.isCredit {
            if account.targetAmount == nil {
                // Credit card: Show available credit
                let available = account.initialAmount - data.balance(for: account)
                return "Available credit: \(available.formattedCurrency(symbol: currencySymbol))"
            }
        } else {
            if account.targetAmount == nil && account.initialAmount > 0 {
                // Debit account: Show change from initial
                let change = data.balance(for: account) - account.initialAmount
                let prefix = change >= 0 ? "+" : ""
                return "Change from start: \(prefix)\(change.formattedCurrency(symbol: currencySymbol))"
            }
        }
        return nil
    }
    
    private func progressBarWidth(current: Double, target: Double, totalWidth: CGFloat) -> CGFloat {
        let percentage = min(max(current / target, 0), 1.0)
        return totalWidth * percentage
    }
    
    private func progressBarColor(current: Double, target: Double) -> Color {
        let percentage = current / target
        
        if account.isCredit {
            // Budget: Green = under budget, Red = over budget
            if percentage > 1.0 {
                return .red
            } else if percentage > 0.9 {
                return .orange
            } else {
                return .green
            }
        } else {
            // Goal: Green when achieved, blue otherwise
            return percentage >= 1.0 ? .green : .blue
        }
    }
    
    // MARK: - View Helpers
    
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

    private func formatFiscalRange(_ range: (start: Date, end: Date)) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }
    
    // MARK: - Logic Helpers
    
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

    private func getCurrentFiscalRange() -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: now)
        
        var startComponents = DateComponents()
        startComponents.year = components.year
        startComponents.month = components.month
        startComponents.day = fiscalStartDay
        
        var start = calendar.date(from: startComponents) ?? now
        
        if now < start {
            start = calendar.date(byAdding: .month, value: -1, to: start) ?? start
        }
        
        let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? now
        return (start, end)
    }
}

// MARK: - Helper View (StatRow already exists in your code)
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
