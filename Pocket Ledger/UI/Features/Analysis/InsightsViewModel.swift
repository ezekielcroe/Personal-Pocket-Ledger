//
//  InsightsViewModel.swift
//  Pocket Ledger
//
//  Owns the Insights page state. Builds a snapshot (InsightsInput) on the
//  main actor, hands it to InsightsEngine on a background task, and
//  publishes the result. A newer calculation always replaces an older one.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class InsightsViewModel: ObservableObject {

    // MARK: - Outputs
    @Published private(set) var result: InsightsResult = .empty
    @Published private(set) var isLoading: Bool = false
    /// Remark Lookup results for `lookupTerm`; nil when the term is empty.
    @Published private(set) var lookup: RemarkTermStats?

    // MARK: - Inputs (View State)
    @Published var timeRange: TimeRange = .thisMonth
    @Published var breakdownMode: BreakdownMode = .category
    /// true = Spending, false = Income. Drives the trend, breakdown and lookup.
    @Published var showsSpending: Bool = true
    @Published var selectedAnchorDate = Date()
    @Published var lookupTerm: String = ""

    /// Signed offset from the current period. 0 = now, -1 = previous, -2 = two periods back, etc.
    @Published var periodOffset: Int = 0

    // MARK: - Filters
    @Published var filters = InsightFilters()
    @Published var selectedPresetID: UUID? = nil

    /// The snapshot behind `result`, reused for lookups and drill-downs so
    /// they use exactly the same period and filters as the page.
    private var lastInput: InsightsInput?
    private var calculationTask: Task<Void, Never>?
    private var lookupTask: Task<Void, Never>?

    /// How many periods the trend chart shows, including the current one.
    private let trendPeriodCount = 6

    // MARK: - Periods

    private var fiscalStartDay: Int {
        UserDefaults.standard.integer(forKey: "fiscalStartDay")
    }

    private func interval(offset: Int) -> DateInterval {
        timeRange.dateInterval(relativeTo: selectedAnchorDate, fiscalStartDay: fiscalStartDay, offset: offset)
    }

    /// The date interval currently displayed.
    var currentDateInterval: DateInterval { interval(offset: periodOffset) }

    var isCurrentPeriodInProgress: Bool {
        timeRange != .allTime && currentDateInterval.contains(Date())
    }

    /// "month", "week" or "year", for sentences like "by this point last month".
    var periodNoun: String {
        switch timeRange {
        case .thisWeek:  return "week"
        case .thisMonth: return "month"
        case .thisYear:  return "year"
        case .allTime:   return "period"
        }
    }

    // MARK: - Period Navigation

    /// Whether a forward arrow should be enabled (can't go past the current period).
    var canGoForward: Bool {
        periodOffset < 0
    }

    /// Whether period navigation makes sense for the selected range.
    var supportsNavigation: Bool {
        timeRange != .allTime
    }

    func goBack() {
        periodOffset -= 1
    }

    func goForward() {
        guard canGoForward else { return }
        periodOffset += 1
    }

    func returnToCurrentPeriod() {
        periodOffset = 0
    }

    // MARK: - Calculation

    /// Recalculates in the background. Call when any input changes.
    func calculate(accountStore: AccountStore, transactionStore: TransactionStore) {
        let input = makeInput(accountStore: accountStore, transactionStore: transactionStore)
        lastInput = input
        isLoading = true

        calculationTask?.cancel()
        calculationTask = Task {
            let computed = await Task.detached(priority: .userInitiated) {
                InsightsEngine.compute(input)
            }.value
            guard !Task.isCancelled else { return }
            self.result = computed
            self.isLoading = false
        }
        refreshLookup()
    }

    /// Recomputes the Remark Lookup after a short pause in typing.
    func refreshLookup() {
        lookupTask?.cancel()
        let term = lookupTerm.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, let input = lastInput else {
            lookup = nil
            return
        }
        lookupTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let stats = await Task.detached(priority: .userInitiated) {
                InsightsEngine.remarkStats(terms: [term], input: input)
            }.value
            guard !Task.isCancelled else { return }
            self.lookup = stats
        }
    }

    /// Stats for a set of remark terms (a bucket), computed with the page's
    /// current period and filters. Used by the bucket drill-down.
    func remarkStats(terms: [String]) async -> RemarkTermStats {
        guard let input = lastInput else { return .empty }
        return await Task.detached(priority: .userInitiated) {
            InsightsEngine.remarkStats(terms: terms, input: input)
        }.value
    }

    // MARK: - Presets

    func apply(_ preset: InsightPreset) {
        filters = preset.filters
        if let mode = preset.breakdownMode { breakdownMode = mode }
        if let showsIncome = preset.showsIncome { showsSpending = !showsIncome }
        selectedPresetID = preset.id
    }

    func resetFilters() {
        filters = InsightFilters()
        selectedPresetID = nil
    }

    // MARK: - Snapshot

    /// Resolves everything main-actor isolated (computed model properties,
    /// group membership, period dates) into plain values for the engine.
    private func makeInput(accountStore: AccountStore, transactionStore: TransactionStore) -> InsightsInput {
        let accounts = accountStore.accounts
        let groups = accountStore.accountGroups
        let categories = transactionStore.categories
        let now = Date()

        // Groups: only top-level groups get a row; a nested group's accounts
        // roll up into its outermost parent. First group wins if an account
        // sits in two top-level groups, so every dollar lands in one row.
        let nestedGroupIDs = Set(groups.flatMap { $0.memberIDs })
        var topLevelGroupOfAccount: [UUID: UUID] = [:]
        for group in groups where !nestedGroupIDs.contains(group.id) {
            for accountID in group.allAccountIDs(in: groups, accounts: accounts)
            where topLevelGroupOfAccount[accountID] == nil {
                topLevelGroupOfAccount[accountID] = group.id
            }
        }

        // Comparison: like-for-like while the current period is in
        // progress ("by this point last month"), else the whole previous one.
        let current = currentDateInterval
        var comparison: DateInterval?
        var likeForLike = false
        if timeRange != .allTime {
            let previous = interval(offset: periodOffset - 1)
            if current.contains(now) {
                let elapsed = now.timeIntervalSince(current.start)
                let end = min(previous.start.addingTimeInterval(elapsed), previous.end)
                comparison = DateInterval(start: previous.start, end: end)
                likeForLike = true
            } else {
                comparison = previous
            }
        }

        return InsightsInput(
            transactions: transactionStore.transactions,
            filters: filters,
            breakdownMode: breakdownMode,
            showsSpending: showsSpending,
            accountTypes: Dictionary(accounts.map { ($0.id, $0.accountType) }, uniquingKeysWith: { a, _ in a }),
            accountNames: Dictionary(accounts.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a }),
            activeAccountIDs: Set(accounts.filter { !$0.isArchived }.map { $0.id }),
            lastReconciled: Dictionary(accounts.compactMap { account in
                account.lastReconciledDate.map { (account.id, $0) }
            }, uniquingKeysWith: { a, _ in a }),
            categories: Dictionary(categories.map {
                ($0.id, InsightCategoryInfo(name: $0.name, emoji: $0.emoji))
            }, uniquingKeysWith: { a, _ in a }),
            plugCategoryIDs: transactionStore.systemCategoryIDs(for: .reconciliationAdjustment),
            topLevelGroupOfAccount: topLevelGroupOfAccount,
            groupNames: Dictionary(groups.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a }),
            buckets: transactionStore.remarkBuckets.map {
                InsightBucketInfo(id: $0.id, name: $0.name, terms: RemarkMatcher.parse($0.terms))
            },
            current: current,
            comparison: comparison,
            comparisonIsLikeForLike: likeForLike,
            trendPeriods: trendPeriods(now: now),
            now: now
        )
    }

    /// The last `trendPeriodCount` periods ending at the one on screen.
    /// "All Time" has no period size, so it uses calendar months.
    private func trendPeriods(now: Date) -> [InsightPeriod] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        switch timeRange {
        case .thisWeek:            formatter.dateFormat = "d MMM"
        case .thisMonth, .allTime: formatter.dateFormat = "MMM"
        case .thisYear:            formatter.dateFormat = "yyyy"
        }

        var periods: [InsightPeriod] = []
        for back in stride(from: trendPeriodCount - 1, through: 0, by: -1) {
            let periodInterval: DateInterval?
            if timeRange == .allTime {
                periodInterval = calendar.date(byAdding: .month, value: -back, to: now)
                    .flatMap { calendar.dateInterval(of: .month, for: $0) }
            } else {
                periodInterval = interval(offset: periodOffset - back)
            }
            guard let periodInterval else { continue }
            periods.append(InsightPeriod(interval: periodInterval,
                                         label: formatter.string(from: periodInterval.start),
                                         isInProgress: periodInterval.contains(now)))
        }
        return periods
    }
}
