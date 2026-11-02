//
//  InsightsView.swift
//  Pocket Ledger
//
//  "Behavioural, not analytical": the page answers "am I on track?" before
//  anything else — where the period's money went across the Four Pillars,
//  compared like-for-like with the previous period, and how far the numbers
//  can be trusted. Every figure opens to the transactions behind it.
//

import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @StateObject private var viewModel = InsightsViewModel()

    @State private var showingFilterSheet = false
    @State private var showingPresetPicker = false
    @State private var showingReconcile = false
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"

    private var result: InsightsResult { viewModel.result }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        pickerSection
                        periodNavigator
                    }

                    if isFilterActive {
                        activeViewBanner
                    }

                    if result.trust.hasConcerns {
                        trustCard
                    }

                    flowsCard

                    trendSection

                    breakdownSection

                    remarkLookupSection
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { filterMenu }
            }
            .onAppear {
                if !availableBreakdownModes.contains(viewModel.breakdownMode) {
                    viewModel.breakdownMode = .category
                }
                recalculate()
            }
            .onChange(of: viewModel.timeRange) { _, _ in
                viewModel.periodOffset = 0   // Reset to current period on range change
                recalculate()
            }
            .onChange(of: viewModel.periodOffset)        { _, _ in recalculate() }
            .onChange(of: viewModel.breakdownMode)       { _, _ in recalculate() }
            .onChange(of: viewModel.showsSpending)       { _, _ in recalculate() }
            .onChange(of: viewModel.filters)             { _, _ in recalculate() }
            .onChange(of: transactionStore.transactions) { _, _ in recalculate() }
            .onChange(of: transactionStore.remarkBuckets) { _, _ in recalculate() }
            // Reconciling changes verification dates (the trust card).
            .onChange(of: accountStore.accounts)         { _, _ in recalculate() }
            .onChange(of: viewModel.lookupTerm)          { _, _ in viewModel.refreshLookup() }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    filters: $viewModel.filters,
                    selectedPresetID: $viewModel.selectedPresetID,
                    breakdownMode: viewModel.breakdownMode,
                    showsSpending: viewModel.showsSpending
                )
                .environmentObject(accountStore)
                .environmentObject(transactionStore)
            }
            .sheet(isPresented: $showingPresetPicker) {
                PresetPickerSheet(
                    selectedPresetID: $viewModel.selectedPresetID,
                    onSelect: { viewModel.apply($0) },
                    onReset: { viewModel.resetFilters() }
                )
                .environmentObject(transactionStore)
            }
            .sheet(isPresented: $showingReconcile) {
                NavigationStack {
                    ReconcileSessionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showingReconcile = false }
                            }
                        }
                }
                .environmentObject(accountStore)
                .environmentObject(transactionStore)
            }
        }
    }

    // MARK: - Header

    var pickerSection: some View {
        Picker("Range", selection: $viewModel.timeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// The current period with back/forward chevrons. Tap the label to jump
    /// back to the current period. "All Time" shows a plain label.
    var periodNavigator: some View {
        Group {
            if viewModel.supportsNavigation {
                HStack(spacing: 16) {
                    Button {
                        viewModel.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous \(viewModel.periodNoun)")

                    Button {
                        viewModel.returnToCurrentPeriod()
                    } label: {
                        Text(periodLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(viewModel.periodOffset == 0 ? .secondary : .primary)
                    }
                    .buttonStyle(.plain)
                    .animation(nil, value: viewModel.periodOffset)
                    .accessibilityHint(viewModel.periodOffset == 0 ? "" : "Returns to the current \(viewModel.periodNoun)")

                    Button {
                        viewModel.goForward()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundColor(viewModel.canGoForward ? .blue : .clear)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canGoForward)
                    .accessibilityLabel("Next \(viewModel.periodNoun)")
                }
            } else {
                Text(periodLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .animation(nil, value: viewModel.timeRange)
            }
        }
    }

    private var periodLabel: String {
        viewModel.timeRange == .allTime ? "All time" : Formatters.formatInterval(viewModel.currentDateInterval)
    }

    private var filterMenu: some View {
        Menu {
            Button { showingFilterSheet = true } label: {
                Label("Filter Data", systemImage: "line.3.horizontal.decrease.circle")
            }
            Button { showingPresetPicker = true } label: {
                Label("Saved Views", systemImage: "bookmark")
            }
        } label: {
            Image(systemName: isFilterActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(isFilterActive ? "Filters, active" : "Filters and saved views")
    }

    var activeViewBanner: some View {
        HStack {
            Image(systemName: viewModel.selectedPresetID != nil
                  ? "bookmark.fill"
                  : "line.3.horizontal.decrease.circle.fill")
            Text(
                viewModel.selectedPresetID != nil
                ? (transactionStore.insightPresets.first(where: { $0.id == viewModel.selectedPresetID })?.name ?? "View")
                : "Custom Filter"
            )
            .fontWeight(.medium)
            Spacer()
            Button("Edit") { showingFilterSheet = true }
            Button("Clear") { viewModel.resetFilters() }
        }
        .font(.caption)
        .padding(10)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - Trust

    /// Shown only when something undermines the figures: accounts used this
    /// period that are overdue for verification, or plugs in the period.
    private var trustCard: some View {
        let trust = result.trust
        return VStack(alignment: .leading, spacing: 8) {
            Label("Some numbers may be incomplete", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)

            if !trust.overdueAccountNames.isEmpty {
                Text(overdueSentence(trust.overdueAccountNames))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !trust.plugTransactions.isEmpty {
                NavigationLink {
                    InsightDrillDownView(
                        title: "Plugs",
                        subtitle: periodLabel,
                        transactions: trust.plugTransactions,
                        footnote: "Adjustments added by Reconcile to match your bank. They're left out of every figure on this page."
                    )
                } label: {
                    HStack {
                        Text("Plugs this \(viewModel.periodNoun): \(trust.plugTotal.formattedCurrency(symbol: currencySymbol))")
                            .font(.caption)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Button("Reconcile now") { showingReconcile = true }
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func overdueSentence(_ names: [String]) -> String {
        switch names.count {
        case 1:
            return "\(names[0]) hasn't been verified against your bank in 30+ days."
        case 2, 3:
            let list = names.dropLast().joined(separator: ", ") + " and " + names.last!
            return "\(list) haven't been verified against your bank in 30+ days."
        default:
            return "\(names.count) accounts used this \(viewModel.periodNoun) haven't been verified against your bank in 30+ days."
        }
    }

    // MARK: - Where It Went (Four Pillars)

    private var hasGoalAccounts: Bool {
        accountStore.accounts.contains { $0.accountType == .goal && !$0.isArchived }
    }

    private var hasDebtAccounts: Bool {
        accountStore.accounts.contains { $0.accountType == .debt && !$0.isArchived }
    }

    private var flowsCard: some View {
        let flows = result.flows
        let previous = result.comparison?.flows

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Where it went")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                }
            }

            if flows.isEmpty {
                Text("No transactions in this period")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                AllocationBar(flows: flows)
                    .frame(height: 10)
                    .accessibilityHidden(true)

                flowRow(title: "Income", amount: flows.income, color: .green,
                        comparison: comparisonLine(current: flows.income, previous: previous?.income, higherIsBetter: true),
                        transactions: result.detail.income)

                flowRow(title: "Spent", amount: flows.spent, color: .red,
                        comparison: comparisonLine(current: flows.spent, previous: previous?.spent, higherIsBetter: false),
                        transactions: result.detail.spending)

                if flows.spentOneOff > 0 {
                    // One-offs shown, not hidden behind a filter: the
                    // difference between a bad month and an unusual one.
                    flowRow(title: "of which one-offs", amount: flows.spentOneOff, color: .red,
                            detail: "Typical spending: \(flows.spentTypical.formattedCurrency(symbol: currencySymbol))",
                            transactions: result.detail.oneOffs, isSubRow: true,
                            footnote: "Transactions flagged as outliers. Flag one-offs when you record them to keep \"typical\" honest.")
                }

                if hasGoalAccounts || flows.savedIn > 0 || flows.savedOut > 0 {
                    flowRow(title: "Saved", amount: flows.savedNet, color: .blue,
                            detail: flows.savedOut > 0
                                ? "In \(flows.savedIn.formattedCurrency(symbol: currencySymbol)) · Taken out \(flows.savedOut.formattedCurrency(symbol: currencySymbol))"
                                : nil,
                            comparison: comparisonLine(current: flows.savedNet, previous: previous?.savedNet, higherIsBetter: true),
                            transactions: result.detail.saving, totalOverride: flows.savedNet,
                            footnote: "Transfers into your Goal accounts, minus anything taken out of them.")
                }

                if hasDebtAccounts || flows.debtPaid > 0 {
                    flowRow(title: "Debt paid", amount: flows.debtPaid, color: .orange,
                            comparison: comparisonLine(current: flows.debtPaid, previous: previous?.debtPaid, higherIsBetter: true),
                            transactions: result.detail.debt,
                            footnote: "Transfers into your Debt accounts. Every one shrinks a balance toward zero.")
                }

                Divider()

                leftOverRow(flows.leftOver)
            }
        }
        .insightCard()
    }

    @ViewBuilder
    private func flowRow(title: String, amount: Decimal, color: Color,
                         detail: String? = nil,
                         comparison: ComparisonLine? = nil,
                         transactions: [Transaction],
                         totalOverride: Decimal? = nil,
                         isSubRow: Bool = false,
                         footnote: String? = nil) -> some View {
        NavigationLink {
            InsightDrillDownView(title: isSubRow ? "One-offs" : title,
                                 subtitle: periodLabel,
                                 transactions: transactions,
                                 totalOverride: totalOverride,
                                 footnote: footnote)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle().fill(color).frame(width: 8, height: 8)
                            .opacity(isSubRow ? 0 : 1)
                        Text(title)
                            .font(isSubRow ? .caption : .subheadline)
                            .foregroundColor(isSubRow ? .secondary : .primary)
                    }
                    if let detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                    }
                    if let comparison {
                        HStack(spacing: 3) {
                            Image(systemName: comparison.symbol)
                            Text(comparison.text)
                        }
                        .font(.caption2)
                        .foregroundColor(comparison.color)
                        .padding(.leading, 14)
                    }
                }
                Spacer()
                Text(amount.formattedCurrency(symbol: currencySymbol))
                    .font(isSubRow ? .caption.monospacedDigit() : .subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(isSubRow ? .secondary : .primary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }

    private func leftOverRow(_ leftOver: Decimal) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(leftOver >= 0 ? "Left over" : "Overspent")
                    .font(.subheadline.weight(.semibold))
                Text("Income minus spending, saving and debt payments")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(abs(leftOver).formattedCurrency(symbol: currencySymbol))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(leftOver >= 0 ? .green : .red)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Comparison

    struct ComparisonLine {
        let text: String
        let symbol: String
        let color: Color
    }

    /// "↑ $510 by this point last month" while the period is in progress
    /// (a fair comparison), or "↓ $2,900 previous month" for past periods.
    private func comparisonLine(current: Decimal, previous: Decimal?, higherIsBetter: Bool) -> ComparisonLine? {
        guard let comparison = result.comparison, let previous else { return nil }
        if current == 0 && previous == 0 { return nil }

        let noun = viewModel.periodNoun
        let phrase = comparison.isLikeForLike ? "by this point last \(noun)" : "previous \(noun)"
        let text = "\(previous.formattedCurrency(symbol: currencySymbol)) \(phrase)"

        if current == previous {
            return ComparisonLine(text: text, symbol: "equal", color: .secondary)
        }
        let isUp = current > previous
        let isGood = isUp == higherIsBetter
        return ComparisonLine(text: text,
                              symbol: isUp ? "arrow.up" : "arrow.down",
                              color: isGood ? .green : .red)
    }

    // MARK: - Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trend")
                    .font(.headline)
                Spacer()
                // This toggle also drives the breakdown and the lookup below.
                Picker("View", selection: $viewModel.showsSpending) {
                    Text("Spending").tag(true)
                    Text("Income").tag(false)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            RemarkTrendChart(points: result.trend, currencySymbol: currencySymbol, typical: result.trendTypical)
                .frame(height: 150)

            if let typical = result.trendTypical {
                Text("Dashed line: your typical \(viewModel.periodNoun), \(typical.formattedCurrency(symbol: currencySymbol)) (average of the earlier \(viewModel.periodNoun)s shown). The lighter bar is still in progress.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Breakdown

    /// Group mode is pointless with no groups defined — everything would
    /// land in one "Ungrouped" row — so it's hidden until a group exists.
    private var availableBreakdownModes: [BreakdownMode] {
        BreakdownMode.allCases.filter { mode in
            mode != .group || !accountStore.accountGroups.isEmpty
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.showsSpending ? "Spending by" : "Income by")
                    .font(.headline)
                Picker("Breakdown", selection: $viewModel.breakdownMode) {
                    ForEach(availableBreakdownModes, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer()
            }
            .padding(.horizontal)

            if result.breakdown.isEmpty {
                contentUnavailableView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(result.breakdown) { item in
                        NavigationLink {
                            drillDown(for: item)
                        } label: {
                            BreakdownBarRow(
                                item: item,
                                scale: result.breakdownScale,
                                showsPercentage: result.breakdownShowsPercentages,
                                currencySymbol: currencySymbol
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Every row opens to exactly the transactions that make up its amount.
    @ViewBuilder
    private func drillDown(for item: AnalyticsItem) -> some View {
        switch item.kind {
        case .category:
            InsightDrillDownView(title: item.name, subtitle: periodLabel,
                                 transactions: item.transactions, emoji: item.emoji)
        case .account:
            InsightDrillDownView(title: item.name, subtitle: periodLabel,
                                 transactions: item.transactions,
                                 account: accountStore.accounts.first(where: { $0.id == item.id }))
        case .group:
            InsightDrillDownView(title: item.name, subtitle: periodLabel,
                                 transactions: item.transactions,
                                 group: accountStore.accountGroups.first(where: { $0.id == item.id }))
        case .ungrouped:
            InsightDrillDownView(title: item.name, subtitle: periodLabel,
                                 transactions: item.transactions,
                                 footnote: "Accounts that aren't in any group.")
        case .bucket:
            let bucket = transactionStore.remarkBuckets.first(where: { $0.id == item.id })
            InsightDrillDownView(title: item.name, subtitle: periodLabel,
                                 transactions: item.transactions,
                                 footnote: bucket.map { "Terms: \($0.terms.joined(separator: ", ")). One transaction can count toward several buckets." },
                                 trendTerms: bucket?.terms,
                                 insights: viewModel)
        case .unmatched:
            InsightDrillDownView(title: "Unmatched", subtitle: periodLabel,
                                 transactions: item.transactions,
                                 footnote: "Not caught by any bucket.",
                                 suggestsBucketTerms: true)
        }
    }

    var contentUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            if viewModel.breakdownMode == .bucket && transactionStore.remarkBuckets.isEmpty {
                Text("No buckets yet")
                    .foregroundColor(.secondary)
                Text("Search a remark term below and save it as a bucket, or create one directly.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                NavigationLink(destination: ManageBucketsView()) {
                    Text("Manage Buckets")
                        .font(.subheadline)
                }
            } else {
                Text("No data found for this period")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Remark Lookup

    /// Ad-hoc stats for any remark term: total, count, average, and a trend
    /// over recent periods — all respecting the current filters and toggle.
    /// Computed in the background after a short pause in typing.
    private var remarkLookupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Remark Lookup")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: ManageBucketsView()) {
                    Text("Buckets")
                        .font(.subheadline)
                }
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("e.g. starbucks", text: $viewModel.lookupTerm)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !viewModel.lookupTerm.isEmpty {
                    Button {
                        viewModel.lookupTerm = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Clear lookup")
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)

            let term = viewModel.lookupTerm.trimmingCharacters(in: .whitespaces)
            if !term.isEmpty, let stats = viewModel.lookup {
                if stats.count == 0 && stats.trend.allSatisfy({ $0.amount == 0 }) {
                    Text("No matching \(viewModel.showsSpending ? "spending" : "income") found.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    NavigationLink {
                        InsightDrillDownView(title: "“\(term)”", subtitle: periodLabel,
                                             transactions: stats.transactions,
                                             trendTerms: [term], insights: viewModel)
                    } label: {
                        HStack(spacing: 0) {
                            lookupStat(label: "Total", value: stats.total.formattedCurrency(symbol: currencySymbol))
                            lookupStat(label: "Count", value: "\(stats.count)")
                            lookupStat(label: "Average", value: stats.average.formattedCurrency(symbol: currencySymbol))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    RemarkTrendChart(points: stats.trend, currencySymbol: currencySymbol)
                        .frame(height: 120)
                }

                bucketSaveRow(for: term)
            }
        }
        .padding(.horizontal)
    }

    private func lookupStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func bucketSaveRow(for term: String) -> some View {
        let owning = transactionStore.remarkBuckets.first { bucket in
            bucket.terms.contains { $0.caseInsensitiveCompare(term) == .orderedSame }
        }

        if let owning {
            Text("In bucket: \(owning.name)")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Button {
                let bucket = RemarkBucket(name: term.capitalized, terms: [term.lowercased()])
                transactionStore.saveBucket(bucket)
            } label: {
                Label("Save as Bucket", systemImage: "plus.circle")
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Logic Helpers

    private var isFilterActive: Bool {
        !viewModel.filters.isEmpty
    }

    private func recalculate() {
        viewModel.calculate(accountStore: accountStore, transactionStore: transactionStore)
    }
}

// MARK: - Card Style

private extension View {
    func insightCard() -> some View {
        self
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
    }
}

// MARK: - Allocation Bar

/// Where the period's money went, as one bar: spent, saved, debt paid, and
/// what's left. Scaled to income, or to total outgoings if those exceed it.
private struct AllocationBar: View {
    let flows: PillarFlows

    private var segments: [(Decimal, Color)] {
        [
            (flows.spent, .red),
            (max(flows.savedNet, 0), .blue),
            (flows.debtPaid, .orange),
            (max(flows.leftOver, 0), .green),
        ].filter { $0.0 > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let total = segments.reduce(Decimal(0)) { $0 + $1.0 }
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let ratio = total > 0
                        ? NSDecimalNumber(decimal: segment.0).doubleValue / NSDecimalNumber(decimal: total).doubleValue
                        : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(segment.1)
                        .frame(width: max(0, geometry.size.width * ratio - 2))
                }
            }
        }
    }
}

// MARK: - Breakdown Bar Row

struct BreakdownBarRow: View {
    let item: AnalyticsItem
    /// The period total, or the largest row when rows overlap (buckets).
    let scale: Decimal
    let showsPercentage: Bool
    let currencySymbol: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                icon
                    .frame(width: 22)

                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text(item.amount.formattedCurrency(symbol: currencySymbol))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(.primary)

                    if showsPercentage && scale > 0 {
                        // Decimal division yields 38-digit mantissas that
                        // overflow NSDecimalNumber.intValue (it returns 0),
                        // so convert through Double instead.
                        let pct = NSDecimalNumber(decimal: item.amount).doubleValue
                                / NSDecimalNumber(decimal: scale).doubleValue * 100
                        Text("\(Int(pct.rounded()))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 6)

                    Capsule()
                        .fill(tint)
                        .frame(width: barWidth(totalWidth: geometry.size.width), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        if item.kind == .category, !item.emoji.isEmpty {
            Text(item.emoji)
        } else {
            Image(systemName: systemImage)
                .foregroundColor(tint)
        }
    }

    private var systemImage: String {
        switch item.kind {
        case .category:  return "tag"
        case .account:   return item.accountType?.icon ?? "building.columns"
        case .group:     return "folder.fill"
        case .bucket:    return "text.magnifyingglass"
        case .ungrouped: return "building.columns"
        case .unmatched: return "questionmark.circle"
        }
    }

    private var tint: Color {
        switch item.kind {
        case .category:               return .primary
        case .account:                return item.accountType?.color ?? .primary
        case .group:                  return .purple
        case .bucket:                 return .teal
        case .ungrouped, .unmatched:  return .secondary
        }
    }

    private func barWidth(totalWidth: CGFloat) -> CGFloat {
        guard scale > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: item.amount).doubleValue / NSDecimalNumber(decimal: scale).doubleValue
        return totalWidth * CGFloat(min(max(ratio, 0.0), 1.0))
    }
}

// MARK: - Preset Picker Sheet

struct PresetPickerSheet: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss

    @Binding var selectedPresetID: UUID?
    let onSelect: (InsightPreset) -> Void
    let onReset: () -> Void

    @State private var presetToEdit: InsightPreset?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onReset()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2").foregroundColor(.blue)
                            Text("All Data")
                            Spacer()
                            if selectedPresetID == nil {
                                Image(systemName: "checkmark").foregroundColor(.blue).fontWeight(.bold)
                            }
                        }
                    }
                }

                if !transactionStore.insightPresets.isEmpty {
                    Section(header: Text("Saved Views")) {
                        ForEach(transactionStore.insightPresets) { preset in
                            Button {
                                onSelect(preset)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill").foregroundColor(.blue)
                                    Text(preset.name)
                                    Spacer()
                                    if selectedPresetID == preset.id {
                                        Image(systemName: "checkmark").foregroundColor(.blue).fontWeight(.bold)
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { presetToEdit = preset } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    transactionStore.deletePreset(preset)
                                    if selectedPresetID == preset.id { onReset() }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("No saved views yet. Create one by applying filters and tapping 'Save View'.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Views")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $presetToEdit) { preset in
                EditPresetSheet(preset: preset)
                    .environmentObject(transactionStore)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Edit Preset Sheet

struct EditPresetSheet: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss

    @AppStorage("currencySymbol") private var currencySymbol: String = "$"

    let preset: InsightPreset
    @State private var presetName: String
    @FocusState private var isNameFieldFocused: Bool

    init(preset: InsightPreset) {
        self.preset = preset
        _presetName = State(initialValue: preset.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("View Name")) {
                    TextField("View Name", text: $presetName)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { if canSave { saveChanges() } }
                }

                Section(
                    header: Text("Filter Summary"),
                    footer: Text("To change filters, apply the view and modify filters from the main screen.")
                ) {
                    PresetFilterSummary(preset: preset, currencySymbol: currencySymbol)
                }
            }
            .navigationTitle("Edit View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { isNameFieldFocused = true }
        }
        .presentationDetents([.medium])
    }

    private var canSave: Bool {
        !presetName.trimmingCharacters(in: .whitespaces).isEmpty && presetName != preset.name
    }

    private func saveChanges() {
        var updatedPreset = preset
        updatedPreset.name = presetName
        transactionStore.savePreset(updatedPreset)
        dismiss()
    }
}
