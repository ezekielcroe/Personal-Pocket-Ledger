import SwiftUI
import UIKit

/// Displays details about an account including its transactions and statistics.
struct AccountDetailView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss
    
    let account: Account

    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
    private var liveAccount: Account {
        accountStore.accounts.first(where: { $0.id == account.id }) ?? account
    }
    
    var body: some View {
        List {
            // SECTION: Archived Banner
            if liveAccount.isArchived {
                Section {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("Archived")
                                .font(.headline)
                            Text("This account is hidden from the main list.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // SECTION 1: Balance
            balanceSection
            
            // SECTION 2: Actions (Unlock/Freeze)
            // Added this here so it appears prominently under the balance
            accountActionSection
            
            // SECTION 3: Verification
            reconciliationStatusSection
            
            // SECTION 4: Target Progress
            if shouldShowTargetProgress {
                targetProgressSection
            }
            
            // SECTION 5: Installment Calculator
            if shouldShowInstallmentCalculator {
                installmentCalculatorSection
            }
            
            // SECTION 6: Statistics
            statisticsSection
            
            // SECTION 7: Recent Transactions
            recentTransactionsSection
            
            // SECTION 8: Archive/Delete Actions
            archiveSection
        }
        
        .onChange(of: liveAccount.accountType) { _, newType in
            let generator = UINotificationFeedbackGenerator()
            
            // Use "Warning" haptic if converting TO Debt, otherwise "Success"
            if newType == .debt {
                generator.notificationOccurred(.warning)
            } else {
                generator.notificationOccurred(.success)
            }
        }
        
        .navigationTitle(liveAccount.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Account", systemImage: "pencil")
                    }
                    
                    if liveAccount.isArchived {
                        Button {
                            withAnimation { accountStore.unarchiveAccount(liveAccount) }
                        } label: {
                            Label("Unarchive", systemImage: "arrow.uturn.backward")
                        }
                    } else {
                        Button {
                            withAnimation { accountStore.archiveAccount(liveAccount) }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAccountView(account: liveAccount)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                accountStore.deleteAccount(liveAccount)
                dismiss() // Pop back to list
            }
        } message: {
            Text("Are you sure? This will permanently remove the account. Associated Transactions will appear as 'Unknown'.")
        }
    }
    
    // MARK: - State Machine Actions (Goal/Budget Conversion)

    @ViewBuilder
    private var accountActionSection: some View {
        let balance = accountStore.balance(for: liveAccount, transactions: transactionStore.transactions)
        
        // SCENARIO 1: Goal -> Debit (The "Unlock" Ceremony)
        if liveAccount.accountType == .goal,
           let target = liveAccount.targetAmount,
           balance >= target {
            
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "lock.open.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Goal Reached!")
                                .font(.headline)
                            Text("Unlock these funds to spend them.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        convertGoalToDebit()
                    } label: {
                        Text("Convert to Spending Account")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        
        // SCENARIO 2: Budget -> Debt (The "Circuit Breaker")
        else if liveAccount.accountType == .limit,
                let limit = liveAccount.targetAmount,
                balance > limit {
            
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "snowflake")
                            .font(.title)
                            .foregroundColor(.blue) // Cold/Frozen metaphor
                        VStack(alignment: .leading) {
                            Text("Budget Exceeded")
                                .font(.headline)
                            Text("Freeze spending on this account?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Converting to Debt prevents further outflows until the balance is paid down.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button {
                        convertBudgetToDebt()
                    } label: {
                        Text("Freeze Account & Convert to Debt")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red) // Warning color
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        
        // SCENARIO 3: Debt -> Budget (Recovery)
        else if liveAccount.accountType == .debt,
                balance <= 0, // Paid off
                liveAccount.isCredit { // Ensure it's a credit account, not a loan
            
            Section {
                Button {
                   showingEditSheet = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reactivate Budget Limit")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        
        // SCENARIO 4: Debit -> Goal (Lock to save)
        else if liveAccount.accountType == .debit {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Saving up for something?")
                        .font(.headline)
                    
                    Text("Lock this account by setting a target amount to convert it into a Goal account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        // Action: Open the Edit Sheet so they can add the Target Amount
                        showingEditSheet = true
                    } label: {
                        Label("Convert to Goal", systemImage: "lock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue) // Matches the Goal color theme
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Reconciliation Traffic Light
        
    @ViewBuilder
    private var reconciliationStatusSection: some View {
        Section(header: Text("Verification Status")) {
            HStack(spacing: 12) {
                // 1. The Light
                Circle()
                    .fill(reconciliationColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: reconciliationColor.opacity(0.5), radius: 4, x: 0, y: 0)
                
                // 2. The Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(reconciliationTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(reconciliationSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Reconciliation Logic
    
    private var daysSinceReconciliation: Int? {
        guard let date = liveAccount.lastReconciledDate else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: start, to: end).day
    }
    
    private var reconciliationColor: Color {
        guard let days = daysSinceReconciliation else { return .red } // Never reconciled
        
        if days < 7 { return .green }      // Fresh
        if days < 30 { return .yellow }    // Stale
        return .red                        // Overdue
    }
    
    private var reconciliationTitle: String {
        guard let days = daysSinceReconciliation else { return "Never Reconciled" }
        
        if days == 0 { return "Verified Today" }
        if days == 1 { return "Verified Yesterday" }
        return "Verified \(days) days ago"
    }
    
    private var reconciliationSubtitle: String {
        guard let days = daysSinceReconciliation else {
            return "Balance accuracy is unverified."
        }
        
        if days < 7 { return "Balance is fresh and trusted." }
        if days < 30 { return "It might be time for a quick check." }
        return "Balance may not match reality."
    }
    
    // MARK: - Balance Section
    
    @ViewBuilder
    private var balanceSection: some View {
        Section {
            VStack(spacing: 12) {
                // Account Type Badge
                HStack {
                    Image(systemName: liveAccount.accountType.icon)
                        .foregroundColor(accountTypeColor)
                    Text(liveAccount.accountType.rawValue + " Account")
                        .font(.subheadline)
                        .foregroundColor(accountTypeColor)
                    Spacer()
                }
                
                // Current Balance
                VStack(alignment: .leading, spacing: 4) {
                    Text(balanceLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(accountStore.balance(for: liveAccount, transactions: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
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
        if let target = liveAccount.targetAmount, target > 0 {
            Section(header: Text(progressSectionTitle)) {
                VStack(spacing: 16) {
                    // Progress Bar
                    progressBar(current: accountStore.balance(for: liveAccount, transactions: transactionStore.transactions), target: target)
                    
                    // Progress Stats
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentAmountLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(accountStore.balance(for: liveAccount, transactions: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
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
                    statusBadge(current: accountStore.balance(for: liveAccount, transactions: transactionStore.transactions), target: target)
                }
                .padding(.vertical, 8)
            }
        } else if liveAccount.accountType == .debt {
            // Debt account with target = 0 or nil
            Section(header: Text("Debt Tracking")) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Debt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(accountStore.balance(for: liveAccount, transactions: transactionStore.transactions).formattedCurrency(symbol: currencySymbol))
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
                    
                    if accountStore.balance(for: liveAccount, transactions: transactionStore.transactions) > 0 {
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
        if let targetDate = liveAccount.targetDate,
           let frequency = liveAccount.paymentFrequency {
            
            Section(header: Text(liveAccount.accountType == .goal ? "Savings Plan" : "Payment Plan")) {
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
                                    .foregroundColor(liveAccount.accountType == .goal ? .blue : .orange)
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
            let stats = FinancialCalculator.stats(for: liveAccount, in: transactionStore.transactions)
            
            // This Period Stats
            switch liveAccount.accountType {
            case .debit, .goal:
                StatRow(title: "Income (This Month)",
                       value: monthlyTotals.inflow,
                       symbol: currencySymbol,
                       color: .green)
                StatRow(title: "Expenses (This Month)",
                       value: monthlyTotals.outflow,
                       symbol: currencySymbol,
                       color: .red)
                
            case .limit:
                StatRow(title: "Spent (This Month)",
                       value: monthlyTotals.outflow,
                       symbol: currencySymbol,
                       color: .red)
                if let target = liveAccount.targetAmount {
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
            switch liveAccount.accountType {
            case .debit, .goal:
                StatRow(title: "Avg Income / Month",
                       value: stats.monthlyInflow,
                       symbol: currencySymbol)
                StatRow(title: "Avg Expenses / Month",
                       value: stats.monthlyOutflow,
                       symbol: currencySymbol)
                
            case .limit:
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
            let recentTransactions = transactionStore.transactions
                .filter { $0.accountID == liveAccount.id }
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
            if liveAccount.isArchived {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.orange)
                        Text("This account is archived")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    if let archivedDate = liveAccount.archivedDate {
                        Text("Archived on \(archivedDate.formatted(date: .long, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Archived accounts are hidden from the main accounts list but their transactions are still included in Insights.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        // Action wrapped in animation for instant visual feedback
                        withAnimation {
                            accountStore.unarchiveAccount(liveAccount)
                        }
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
                    // Action wrapped in animation for instant visual feedback
                    withAnimation {
                        accountStore.archiveAccount(liveAccount)
                    }
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
        if !liveAccount.isArchived {
            return Text("Archive this account to hide it from the main list. You can unarchive it anytime, and all transaction history will be preserved.")
        }
        return nil
    }
    
    // MARK: - Helper Views
        
        @ViewBuilder
        private func progressBar(current: Decimal, target: Decimal) -> some View {
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
        private func statusBadge(current: Decimal, target: Decimal) -> some View {
            switch liveAccount.accountType {
            case .limit:
                let remaining = target - current
                HStack {
                    Image(systemName: remaining >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(remaining >= 0 ? .green : .red)
                    if remaining >= 0 {
                        Text("\(remaining.formattedCurrency(symbol: currencySymbol)) remaining (\(calculatePercent(current: current, target: target))% used)")
                    } else {
                        let overage = remaining * -1
                        Text("Over budget by \(overage.formattedCurrency(symbol: currencySymbol))")
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
                        Text("\(remaining.formattedCurrency(symbol: currencySymbol)) to go (\(calculatePercent(current: current, target: target))% saved)")
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
        
        // Helper to calculate integer percentage from Decimals
        private func calculatePercent(current: Decimal, target: Decimal) -> Int {
            guard target != 0 else { return 0 }
            let fraction = (current / target) as NSDecimalNumber
            return Int(fraction.doubleValue * 100)
        }
    
    // MARK: - Computed Properties
    
    private var shouldShowTargetProgress: Bool {
        if liveAccount.accountType == .debt {
            return true
        }
        return liveAccount.targetAmount != nil && liveAccount.targetAmount! > 0
    }
    
    private var shouldShowInstallmentCalculator: Bool {
        guard liveAccount.targetDate != nil && liveAccount.paymentFrequency != nil else {
            return false
        }
        return liveAccount.accountType == .goal || liveAccount.accountType == .debt
    }
    
    private var accountTypeColor: Color {
        switch liveAccount.accountType {
        case .debit:  return .primary
        case .goal:   return .blue
        case .limit: return .purple
        case .debt:   return .orange
        }
    }
    
    private var balanceLabel: String {
        switch liveAccount.accountType {
        case .debit:  return "Current Balance"
        case .goal:   return "Current Savings"
        case .limit: return "Spent This Period"
        case .debt:   return "Amount Owed"
        }
    }
    
    private var balanceColor: Color {
        let balance = accountStore.balance(for: liveAccount, transactions: transactionStore.transactions)
        
        switch liveAccount.accountType {
        case .debit:
            return balance < 0 ? .red : .primary
            
        case .goal:
            if let target = liveAccount.targetAmount, balance >= target {
                return .green
            }
            return .primary
            
        case .limit:
            if let target = liveAccount.targetAmount {
                return balance > target ? .red : .primary
            }
            return .primary
            
        case .debt:
            return balance > 0 ? .orange : .green
        }
    }
    
    private var balanceSubtitle: String? {
        switch liveAccount.accountType {
        case .debit:
            let change = accountStore.balance(for: liveAccount, transactions: transactionStore.transactions) - liveAccount.initialAmount
            let prefix = change >= 0 ? "+" : ""
            return "Change from start: \(prefix)\(change.formattedCurrency(symbol: currencySymbol))"
            
        default:
            return nil
        }
    }
    
    private var progressSectionTitle: String {
        switch liveAccount.accountType {
        case .goal:   return "Goal Progress"
        case .limit: return "Budget Progress"
        case .debt:   return "Payoff Progress"
        default:      return "Progress"
        }
    }
    
    private var currentAmountLabel: String {
        switch liveAccount.accountType {
        case .goal:   return "Saved"
        case .limit: return "Spent"
        case .debt:   return "Owed"
        default:      return "Current"
        }
    }
    
    private var targetAmountLabel: String {
        switch liveAccount.accountType {
        case .goal:   return "Goal"
        case .limit: return "Budget"
        case .debt:   return "Payoff"
        default:      return "Target"
        }
    }
    
    private func progressBarWidth(current: Decimal, target: Decimal, totalWidth: CGFloat) -> CGFloat {
            guard target != 0 else { return 0 }
            let fraction = (current / target) as NSDecimalNumber
            let percentage = min(max(fraction.doubleValue, 0), 1.0)
            return totalWidth * CGFloat(percentage)
        }
        
        private func progressBarColor(current: Decimal, target: Decimal) -> Color {
            guard target != 0 else { return .blue }
            let fraction = (current / target) as NSDecimalNumber
            let percentage = fraction.doubleValue
            
            switch liveAccount.accountType {
            case .limit:
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
        
        private func calculateInstallment() -> (periodsRemaining: Int, amountPerPeriod: Decimal)? {
            guard let targetDate = liveAccount.targetDate,
                  let frequency = liveAccount.paymentFrequency else {
                return nil
            }
            
            let today = Date()
            // Simple comparison; for exact day logic you might want Calendar calls
            guard targetDate > today else { return nil }
            
            let periodsRemaining = frequency.periodsBetween(from: today, to: targetDate)
            guard periodsRemaining > 0 else { return nil }
            
            let current = accountStore.balance(for: liveAccount, transactions: transactionStore.transactions)
            let remaining: Decimal
            
            switch liveAccount.accountType {
            case .goal:
                if let target = liveAccount.targetAmount {
                    remaining = max(target - current, 0)
                } else {
                    return nil
                }
                
            case .debt:
                remaining = max(current, 0)
                
            default:
                return nil
            }
            
            // Decimal Division
            let amountPerPeriod = remaining / Decimal(periodsRemaining)
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
    
    private func calculateCurrentMonthTotals() -> (inflow: Decimal, outflow: Decimal) {
        let range = getCurrentFiscalRange()
        let accountTransactions = transactionStore.transactions
            .filter { $0.accountID == liveAccount.id }
        
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
    
    // MARK: - Account State Transitions

    private func convertGoalToDebit() {
        // 1. Create a copy of the account
        var updatedAccount = liveAccount
        
        // 2. Remove the target.
        // Logic: isCredit (false) + targetAmount (nil) = .debit
        updatedAccount.targetAmount = nil
        
        // 3. Clear the target date/frequency since it's no longer a goal
        updatedAccount.targetDate = nil
        updatedAccount.paymentFrequency = nil
        
        // 4. Save to Account Store
        if let index = accountStore.accounts.firstIndex(where: { $0.id == updatedAccount.id }) {
            accountStore.accounts[index] = updatedAccount
            accountStore.save() // Triggers persistence and UI updates
        }

    }

    private func convertBudgetToDebt() {
        // 1. Create a copy
        var updatedAccount = liveAccount
        
        // 2. Remove the target (Limit).
        // Logic: isCredit (true) + targetAmount (nil) = .debt
        updatedAccount.targetAmount = nil
        
        // 3. Keep the isCredit = true setting.
        
        // 4. Save
        // FIX: Find the index and replace the struct directly
        if let index = accountStore.accounts.firstIndex(where: { $0.id == updatedAccount.id }) {
            accountStore.accounts[index] = updatedAccount
            accountStore.save()
        }
    }

}

// MARK: - Helper View

/// A consistent row format for displaying labeled monetary values.
struct StatRow: View {
    let title: String
    let value: Decimal
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
