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
            
            // SECTION 2: Target Progress (Goals, Budgets, Debts)
            if shouldShowTargetProgress {
                targetProgressSection
            }
            
            // SECTION 3: Installment Calculator (Goals & Debts with target dates)
            if shouldShowInstallmentCalculator {
                installmentCalculatorSection
            }
            
            // SECTION 4: Statistics
            statisticsSection
            
            // SECTION 5: Recent Transactions
            recentTransactionsSection
            
            // SECTION 6: Archive Controls
            archiveSection
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Balance Section
    
    @ViewBuilder
    private var balanceSection: some View {
        Section {
            VStack(spacing: 12) {
                // Account Type Badge
                HStack {
                    Image(systemName: account.accountType.icon)
                        .foregroundColor(accountTypeColor)
                    Text(account.accountType.rawValue + " Account")
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
    
    // MARK: - Target Progress Section
    
    @ViewBuilder
    private var targetProgressSection: some View {
        if let target = account.targetAmount, target > 0 {
            Section(header: Text(progressSectionTitle)) {
                VStack(spacing: 16) {
                    // Progress Bar
                    progressBar(current: data.balance(for: account), target: target)
                    
                    // Progress Stats
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentAmountLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(targetAmountLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(target.formattedCurrency(symbol: currencySymbol))
                                .font(.headline)
                        }
                    }
                    
                    // Status Badge
                    statusBadge(current: data.balance(for: account), target: target)
                }
                .padding(.vertical, 8)
            }
        } else if account.accountType == .debt {
            // Debt account with target = 0 or nil
            Section(header: Text("Debt Tracking")) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Debt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(data.balance(for: account).formattedCurrency(symbol: currencySymbol))
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Payoff Goal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$0.00")
                                .font(.headline)
                        }
                    }
                    
                    if data.balance(for: account) > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Set a target date to calculate payment plan")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Debt paid off! 🎉")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Installment Calculator Section
    
    @ViewBuilder
    private var installmentCalculatorSection: some View {
        if let targetDate = account.targetDate,
           let frequency = account.paymentFrequency {
            
            Section(header: Text(account.accountType == .goal ? "Savings Plan" : "Payment Plan")) {
                VStack(spacing: 12) {
                    // Target Date
                    HStack {
                        Text("Target Date")
                        Spacer()
                        Text(targetDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Frequency
                    HStack {
                        Text("Payment Frequency")
                        Spacer()
                        Text(frequency.rawValue)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Calculations
                    if let installment = calculateInstallment() {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Payments Remaining")
                                Spacer()
                                Text("\(installment.periodsRemaining)")
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Required per \(frequency.rawValue.lowercased())")
                                Spacer()
                                Text(installment.amountPerPeriod.formattedCurrency(symbol: currencySymbol))
                                    .font(.headline)
                                    .foregroundColor(account.accountType == .goal ? .blue : .orange)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
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
            switch account.accountType {
            case .debit, .goal:
                StatRow(title: "Income (This Month)",
                       value: monthlyTotals.inflow,
                       symbol: currencySymbol,
                       color: .green)
                StatRow(title: "Expenses (This Month)",
                       value: monthlyTotals.outflow,
                       symbol: currencySymbol,
                       color: .red)
                
            case .budget:
                StatRow(title: "Spent (This Month)",
                       value: monthlyTotals.outflow,
                       symbol: currencySymbol,
                       color: .red)
                if let target = account.targetAmount {
                    StatRow(title: "Budget",
                           value: target,
                           symbol: currencySymbol,
                           color: .purple)
                }
                
            case .debt:
                StatRow(title: "Payments Made (This Month)",
                       value: monthlyTotals.inflow,
                       symbol: currencySymbol,
                       color: .green)
                StatRow(title: "New Charges (This Month)",
                       value: monthlyTotals.outflow,
                       symbol: currencySymbol,
                       color: .red)
            }
            
            Divider()
            
            // Average Stats
            switch account.accountType {
            case .debit, .goal:
                StatRow(title: "Avg Income / Month",
                       value: stats.monthlyInflow,
                       symbol: currencySymbol)
                StatRow(title: "Avg Expenses / Month",
                       value: stats.monthlyOutflow,
                       symbol: currencySymbol)
                
            case .budget:
                StatRow(title: "Avg Spending / Month",
                       value: stats.monthlyOutflow,
                       symbol: currencySymbol)
                
            case .debt:
                StatRow(title: "Avg Payment / Month",
                       value: stats.monthlyInflow,
                       symbol: currencySymbol)
                StatRow(title: "Avg New Charges / Month",
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
    
    // MARK: - Archive Section
    
    @ViewBuilder
    private var archiveSection: some View {
        Section(footer: archiveFooter) {
            if account.isArchived {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.orange)
                        Text("This account is archived")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    if let archivedDate = account.archivedDate {
                        Text("Archived on \(archivedDate.formatted(date: .long, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Archived accounts are hidden from the main accounts list but their transactions are still included in Insights.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        data.unarchiveAccount(account)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                            Text("Unarchive Account")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            } else {
                Button(role: .destructive) {
                    data.archiveAccount(account)
                } label: {
                    HStack {
                        Image(systemName: "archivebox")
                        Text("Archive Account")
                    }
                }
            }
        }
    }
    
    private var archiveFooter: Text? {
        if !account.isArchived {
            return Text("Archive this account to hide it from the main list. You can unarchive it anytime, and all transaction history will be preserved.")
        }
        return nil
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func progressBar(current: Double, target: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(progressBarColor(current: current, target: target))
                    .frame(width: progressBarWidth(current: current, target: target, totalWidth: geometry.size.width),
                           height: 12)
            }
        }
        .frame(height: 12)
    }
    
    @ViewBuilder
    private func statusBadge(current: Double, target: Double) -> some View {
        switch account.accountType {
        case .budget:
            let remaining = target - current
            HStack {
                Image(systemName: remaining >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(remaining >= 0 ? .green : .red)
                if remaining >= 0 {
                    Text("\(remaining.formattedCurrency(symbol: currencySymbol)) remaining (\(Int((current/target)*100))% used)")
                } else {
                    Text("Over budget by \(abs(remaining).formattedCurrency(symbol: currencySymbol))")
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(remaining >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(8)
            
        case .goal:
            if current >= target {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Goal reached! 🎉")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                let remaining = target - current
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                    Text("\(remaining.formattedCurrency(symbol: currencySymbol)) to go (\(Int((current/target)*100))% saved)")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Computed Properties
    
    private var shouldShowTargetProgress: Bool {
        if account.accountType == .debt {
            return true
        }
        return account.targetAmount != nil && account.targetAmount! > 0
    }
    
    private var shouldShowInstallmentCalculator: Bool {
        guard account.targetDate != nil && account.paymentFrequency != nil else {
            return false
        }
        return account.accountType == .goal || account.accountType == .debt
    }
    
    private var accountTypeColor: Color {
        switch account.accountType {
        case .debit:  return .primary
        case .goal:   return .blue
        case .budget: return .purple
        case .debt:   return .orange
        }
    }
    
    private var balanceLabel: String {
        switch account.accountType {
        case .debit:  return "Current Balance"
        case .goal:   return "Current Savings"
        case .budget: return "Spent This Period"
        case .debt:   return "Amount Owed"
        }
    }
    
    private var balanceColor: Color {
        let balance = data.balance(for: account)
        
        switch account.accountType {
        case .debit:
            return balance < 0 ? .red : .primary
            
        case .goal:
            if let target = account.targetAmount, balance >= target {
                return .green
            }
            return .primary
            
        case .budget:
            if let target = account.targetAmount {
                return balance > target ? .red : .primary
            }
            return .primary
            
        case .debt:
            return balance > 0 ? .orange : .green
        }
    }
    
    private var balanceSubtitle: String? {
        switch account.accountType {
        case .debit:
            let change = data.balance(for: account) - account.initialAmount
            let prefix = change >= 0 ? "+" : ""
            return "Change from start: \(prefix)\(change.formattedCurrency(symbol: currencySymbol))"
            
        default:
            return nil
        }
    }
    
    private var progressSectionTitle: String {
        switch account.accountType {
        case .goal:   return "Goal Progress"
        case .budget: return "Budget Progress"
        case .debt:   return "Payoff Progress"
        default:      return "Progress"
        }
    }
    
    private var currentAmountLabel: String {
        switch account.accountType {
        case .goal:   return "Saved"
        case .budget: return "Spent"
        case .debt:   return "Owed"
        default:      return "Current"
        }
    }
    
    private var targetAmountLabel: String {
        switch account.accountType {
        case .goal:   return "Goal"
        case .budget: return "Budget"
        case .debt:   return "Payoff"
        default:      return "Target"
        }
    }
    
    private func progressBarWidth(current: Double, target: Double, totalWidth: CGFloat) -> CGFloat {
        let percentage = min(max(current / target, 0), 1.0)
        return totalWidth * percentage
    }
    
    private func progressBarColor(current: Double, target: Double) -> Color {
        let percentage = current / target
        
        switch account.accountType {
        case .budget:
            if percentage > 1.0 { return .red }
            else if percentage > 0.9 { return .orange }
            else { return .green }
            
        case .goal:
            return percentage >= 1.0 ? .green : .blue
            
        case .debt:
            return .orange
            
        default:
            return .blue
        }
    }
    
    // MARK: - Installment Calculation
    
    private func calculateInstallment() -> (periodsRemaining: Int, amountPerPeriod: Double)? {
        guard let targetDate = account.targetDate,
              let frequency = account.paymentFrequency else {
            return nil
        }
        
        let today = Date()
        guard targetDate > today else { return nil }
        
        let periodsRemaining = frequency.periodsBetween(from: today, to: targetDate)
        guard periodsRemaining > 0 else { return nil }
        
        let current = data.balance(for: account)
        let remaining: Double
        
        switch account.accountType {
        case .goal:
            if let target = account.targetAmount {
                remaining = max(target - current, 0)
            } else {
                return nil
            }
            
        case .debt:
            remaining = max(current, 0)
            
        default:
            return nil
        }
        
        let amountPerPeriod = remaining / Double(periodsRemaining)
        return (periodsRemaining, amountPerPeriod)
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
