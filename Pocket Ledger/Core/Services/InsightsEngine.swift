//
//  InsightsEngine.swift
//  Pocket Ledger
//
//  All Insights arithmetic, as pure functions over a snapshot. Runs off the
//  main thread.
//
//  Concurrency note: the project's Default Actor Isolation is MainActor, so
//  every type here is explicitly `nonisolated`, and the snapshot carries
//  only plain stored values. Model computed properties such as
//  `Account.accountType` are main-actor isolated, so InsightsViewModel
//  resolves them on the main actor while building `InsightsInput`.
//
//  How money is counted (the Four Pillars):
//  - Income      regular inflows
//  - Spent       regular outflows, split into typical and one-offs (outliers)
//  - Saved       transfers into Goal accounts, minus transfers out of Goals
//  - Debt paid   transfers into Debt accounts
//  - Left over   income − spent − saved − debt paid
//  Transfers are recognised structurally (a linked pair), never by category
//  name. Reconciliation plugs are left out of every figure and reported
//  separately under "trust".
//

import Foundation

// MARK: - Input

nonisolated struct InsightFilters: Sendable, Equatable {
    var excludedAccountIDs: Set<UUID> = []
    var excludedCategoryIDs: Set<UUID> = []
    var excludeOutliers = false
    var minimumAmount: Decimal? = nil
    var maximumAmount: Decimal? = nil

    var isEmpty: Bool {
        excludedAccountIDs.isEmpty && excludedCategoryIDs.isEmpty &&
        !excludeOutliers && minimumAmount == nil && maximumAmount == nil
    }
}

nonisolated struct InsightPeriod: Sendable {
    let interval: DateInterval
    let label: String
    /// The period containing "now"; its figures are still growing.
    let isInProgress: Bool
}

nonisolated struct InsightCategoryInfo: Sendable {
    let name: String
    let emoji: String
}

nonisolated struct InsightBucketInfo: Sendable {
    let id: UUID
    let name: String
    /// Parsed with RemarkMatcher.
    let terms: [RemarkTerm]
}

/// Everything the engine needs, resolved on the main actor.
nonisolated struct InsightsInput: Sendable {
    var transactions: [Transaction]
    var filters: InsightFilters
    var breakdownMode: BreakdownMode
    /// true = spending view, false = income view.
    var showsSpending: Bool

    var accountTypes: [UUID: AccountType]
    var accountNames: [UUID: String]
    var activeAccountIDs: Set<UUID>
    var lastReconciled: [UUID: Date]
    var categories: [UUID: InsightCategoryInfo]
    var plugCategoryIDs: Set<UUID>
    /// Each grouped account's outermost (top-level) group.
    var topLevelGroupOfAccount: [UUID: UUID]
    var groupNames: [UUID: String]
    var buckets: [InsightBucketInfo]

    var current: DateInterval
    /// Like-for-like slice of the previous period when the current one is in
    /// progress, the whole previous period otherwise, nil for All Time.
    var comparison: DateInterval?
    var comparisonIsLikeForLike: Bool
    /// Oldest first; the last one is the period on screen.
    var trendPeriods: [InsightPeriod]
    var now: Date
}

// MARK: - Results

nonisolated struct PillarFlows: Sendable {
    var income: Decimal = 0
    var spentTypical: Decimal = 0
    var spentOneOff: Decimal = 0
    var savedIn: Decimal = 0
    var savedOut: Decimal = 0
    var debtPaid: Decimal = 0

    var spent: Decimal { spentTypical + spentOneOff }
    var savedNet: Decimal { savedIn - savedOut }
    var leftOver: Decimal { income - spent - savedNet - debtPaid }
    var isEmpty: Bool { income == 0 && spent == 0 && savedIn == 0 && savedOut == 0 && debtPaid == 0 }
}

/// The transactions behind each pillar figure, for drill-downs.
nonisolated struct PillarDetail: Sendable {
    var income: [Transaction] = []
    var spending: [Transaction] = []
    var oneOffs: [Transaction] = []
    /// Inflow legs of transfers into (or out of) Goals.
    var saving: [Transaction] = []
    /// Inflow legs of transfers into Debt accounts.
    var debt: [Transaction] = []
}

nonisolated struct PeriodComparison: Sendable {
    let interval: DateInterval
    /// true: "by this point last month"; false: "previous month".
    let isLikeForLike: Bool
    let flows: PillarFlows
}

nonisolated struct TrustSummary: Sendable {
    /// Accounts used this period that haven't been verified in 30+ days
    /// (the red traffic light), sorted by name.
    var overdueAccountNames: [String] = []
    var plugTotal: Decimal = 0
    var plugTransactions: [Transaction] = []

    var hasConcerns: Bool { !overdueAccountNames.isEmpty || !plugTransactions.isEmpty }
}

nonisolated enum AnalyticsItemKind: Hashable, Sendable {
    case category, account, group, bucket
    /// Spending on accounts in no group.
    case ungrouped
    /// Spending no bucket caught.
    case unmatched
}

nonisolated struct AnalyticsItem: Identifiable, Sendable {
    static let ungroupedID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    static let unmatchedID = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!

    let id: UUID
    let kind: AnalyticsItemKind
    let name: String
    /// Category emoji; empty for other kinds (the view picks an icon).
    let emoji: String
    /// For account rows, so the view can tint and icon by type.
    let accountType: AccountType?
    let amount: Decimal
    let transactions: [Transaction]
}

nonisolated struct TrendPoint: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let amount: Decimal
    var isInProgress: Bool = false
}

nonisolated struct RemarkTermStats: Sendable {
    let total: Decimal
    let count: Int
    let average: Decimal
    let trend: [TrendPoint]
    let transactions: [Transaction]

    static let empty = RemarkTermStats(total: 0, count: 0, average: 0, trend: [], transactions: [])
}

nonisolated struct InsightsResult: Sendable {
    var flows = PillarFlows()
    var detail = PillarDetail()
    var comparison: PeriodComparison?
    var breakdown: [AnalyticsItem] = []
    /// Bar scale: the period total, or the largest row for buckets (which
    /// overlap, so a shared total would misstate their shares).
    var breakdownScale: Decimal = 0
    var breakdownShowsPercentages = true
    var trend: [TrendPoint] = []
    /// Average of the earlier, complete periods in the trend (only those
    /// after your first transaction); nil when there are fewer than two.
    var trendTypical: Decimal?
    var trust = TrustSummary()

    static let empty = InsightsResult()
}

// MARK: - Engine

nonisolated enum InsightsEngine {

    static func compute(_ input: InsightsInput) -> InsightsResult {
        let byID = index(input.transactions)
        let current = scan(input, interval: input.current, byID: byID, collect: true)

        var result = InsightsResult()
        result.flows = current.flows
        result.detail = current.detail

        if let interval = input.comparison {
            let previous = scan(input, interval: interval, byID: byID, collect: false)
            result.comparison = PeriodComparison(interval: interval,
                                                 isLikeForLike: input.comparisonIsLikeForLike,
                                                 flows: previous.flows)
        }

        let breakdown = makeBreakdown(current.eligible, input: input)
        result.breakdown = breakdown.items
        result.breakdownScale = breakdown.scale
        result.breakdownShowsPercentages = breakdown.showsPercentages

        // Trend
        var trend: [TrendPoint] = []
        var earlierAmounts: [Decimal] = []
        let firstDate = input.transactions.map { $0.date }.min()
        for (offset, period) in input.trendPeriods.enumerated() {
            let flows = scan(input, interval: period.interval, byID: byID, collect: false).flows
            let amount = input.showsSpending ? flows.spent : flows.income
            trend.append(TrendPoint(label: period.label, amount: amount, isInProgress: period.isInProgress))
            let isLast = offset == input.trendPeriods.count - 1
            if !isLast, !period.isInProgress, let firstDate, period.interval.end > firstDate {
                earlierAmounts.append(amount)
            }
        }
        result.trend = trend
        if earlierAmounts.count >= 2 {
            result.trendTypical = earlierAmounts.reduce(0, +) / Decimal(earlierAmounts.count)
        }

        result.trust = trust(input)
        return result
    }

    /// Totals, count, average and trend for transactions whose remark matches
    /// any of `terms` (RemarkMatcher syntax), using the same period, filters
    /// and Spending/Income view as the page — so a bucket's numbers agree
    /// with its row.
    static func remarkStats(terms: [String], input: InsightsInput) -> RemarkTermStats {
        let parsed = RemarkMatcher.parse(terms)
        guard !parsed.isEmpty else { return .empty }
        let byID = index(input.transactions)

        func matching(in interval: DateInterval) -> [Transaction] {
            scan(input, interval: interval, byID: byID, collect: true)
                .eligible.filter { RemarkMatcher.matches($0.remark, anyOf: parsed) }
        }

        let current = matching(in: input.current)
        let total = current.reduce(Decimal(0)) { $0 + $1.amount }

        let trend = input.trendPeriods.map { period -> TrendPoint in
            let amount = matching(in: period.interval).reduce(Decimal(0)) { $0 + $1.amount }
            return TrendPoint(label: period.label, amount: amount, isInProgress: period.isInProgress)
        }

        return RemarkTermStats(
            total: total,
            count: current.count,
            average: current.isEmpty ? 0 : total / Decimal(current.count),
            trend: trend,
            transactions: current.sorted { $0.date > $1.date }
        )
    }

    // MARK: - Scan

    private struct Scan {
        var flows = PillarFlows()
        var detail = PillarDetail()
        /// Regular transactions of the Spending/Income view, for breakdowns.
        var eligible: [Transaction] = []
    }

    private static func index(_ transactions: [Transaction]) -> [UUID: Transaction] {
        Dictionary(transactions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// One pass over history for one period. `collect` also gathers the
    /// transactions behind each figure (skipped for trend/comparison passes).
    private static func scan(_ input: InsightsInput, interval: DateInterval,
                             byID: [UUID: Transaction], collect: Bool) -> Scan {
        var s = Scan()
        let filters = input.filters

        for tx in input.transactions {
            guard interval.contains(tx.date) else { continue }

            // Transfers: classify by the inflow (destination) leg only, so a
            // pair is counted once.
            if let linkedID = tx.linkedTransactionID {
                guard case .inflow = tx.type else { continue }
                guard passes(tx, filters, checkAccount: false) else { continue }
                let partner = byID[linkedID]
                if filters.excludedAccountIDs.contains(tx.accountID) { continue }
                if let partner, filters.excludedAccountIDs.contains(partner.accountID) { continue }

                let destination = input.accountTypes[tx.accountID]
                let source = partner.flatMap { input.accountTypes[$0.accountID] }

                if isGoal(destination) && !isGoal(source) {
                    s.flows.savedIn += tx.amount
                    if collect { s.detail.saving.append(tx) }
                } else if isGoal(source) && !isGoal(destination) {
                    s.flows.savedOut += tx.amount
                    if collect { s.detail.saving.append(tx) }
                }
                if isDebt(destination) && !isDebt(source) {
                    s.flows.debtPaid += tx.amount
                    if collect { s.detail.debt.append(tx) }
                }
                continue
            }

            // Plugs never count as income or spending.
            if input.plugCategoryIDs.contains(tx.categoryID) { continue }
            guard passes(tx, filters, checkAccount: true) else { continue }

            switch tx.type {
            case .inflow:
                s.flows.income += tx.amount
                if collect {
                    s.detail.income.append(tx)
                    if !input.showsSpending { s.eligible.append(tx) }
                }
            case .outflow:
                if tx.isOutlier {
                    s.flows.spentOneOff += tx.amount
                    if collect { s.detail.oneOffs.append(tx) }
                } else {
                    s.flows.spentTypical += tx.amount
                }
                if collect {
                    s.detail.spending.append(tx)
                    if input.showsSpending { s.eligible.append(tx) }
                }
            case .transfer:
                break // never stored: transfers are saved as linked legs
            }
        }
        return s
    }

    private static func passes(_ tx: Transaction, _ f: InsightFilters, checkAccount: Bool) -> Bool {
        if f.excludeOutliers && tx.isOutlier { return false }
        if checkAccount && f.excludedAccountIDs.contains(tx.accountID) { return false }
        if f.excludedCategoryIDs.contains(tx.categoryID) { return false }
        if let min = f.minimumAmount, tx.amount < min { return false }
        if let max = f.maximumAmount, tx.amount > max { return false }
        return true
    }

    private static func isGoal(_ type: AccountType?) -> Bool {
        if case .goal? = type { return true }
        return false
    }

    private static func isDebt(_ type: AccountType?) -> Bool {
        if case .debt? = type { return true }
        return false
    }

    // MARK: - Breakdown

    private static func makeBreakdown(_ eligible: [Transaction], input: InsightsInput)
        -> (items: [AnalyticsItem], scale: Decimal, showsPercentages: Bool) {

        let total = eligible.reduce(Decimal(0)) { $0 + $1.amount }

        func grouped(by key: (Transaction) -> UUID?) -> (groups: [UUID: [Transaction]], rest: [Transaction]) {
            var groups: [UUID: [Transaction]] = [:]
            var rest: [Transaction] = []
            for tx in eligible {
                if let k = key(tx) { groups[k, default: []].append(tx) } else { rest.append(tx) }
            }
            return (groups, rest)
        }

        func sum(_ list: [Transaction]) -> Decimal { list.reduce(Decimal(0)) { $0 + $1.amount } }

        var items: [AnalyticsItem] = []
        var pseudo: AnalyticsItem?
        var showsPercentages = true

        switch input.breakdownMode {
        case .category:
            for (id, list) in grouped(by: { $0.categoryID }).groups {
                let info = input.categories[id]
                items.append(AnalyticsItem(id: id, kind: .category, name: info?.name ?? "Uncategorized",
                                           emoji: info?.emoji ?? "", accountType: nil,
                                           amount: sum(list), transactions: list))
            }

        case .account:
            for (id, list) in grouped(by: { $0.accountID }).groups {
                items.append(AnalyticsItem(id: id, kind: .account, name: input.accountNames[id] ?? "Unknown",
                                           emoji: "", accountType: input.accountTypes[id],
                                           amount: sum(list), transactions: list))
            }

        case .group:
            let split = grouped(by: { input.topLevelGroupOfAccount[$0.accountID] })
            for (id, list) in split.groups {
                items.append(AnalyticsItem(id: id, kind: .group, name: input.groupNames[id] ?? "Group",
                                           emoji: "", accountType: nil,
                                           amount: sum(list), transactions: list))
            }
            if !split.rest.isEmpty {
                pseudo = AnalyticsItem(id: AnalyticsItem.ungroupedID, kind: .ungrouped, name: "Ungrouped",
                                       emoji: "", accountType: nil,
                                       amount: sum(split.rest), transactions: split.rest)
            }

        case .bucket:
            // Buckets overlap: one transaction can feed several, so rows are
            // absolute totals rather than shares of a whole.
            showsPercentages = false
            var unmatched: [Transaction] = []
            var byBucket: [UUID: [Transaction]] = [:]
            for tx in eligible {
                var matchedAny = false
                let tokens = RemarkMatcher.tokens(of: tx.remark) // once per transaction
                for bucket in input.buckets where RemarkMatcher.matches(tokens, anyOf: bucket.terms) {
                    byBucket[bucket.id, default: []].append(tx)
                    matchedAny = true
                }
                if !matchedAny { unmatched.append(tx) }
            }
            for bucket in input.buckets {
                guard let list = byBucket[bucket.id] else { continue }
                items.append(AnalyticsItem(id: bucket.id, kind: .bucket, name: bucket.name,
                                           emoji: "", accountType: nil,
                                           amount: sum(list), transactions: list))
            }
            if !unmatched.isEmpty {
                pseudo = AnalyticsItem(id: AnalyticsItem.unmatchedID, kind: .unmatched, name: "Unmatched",
                                       emoji: "", accountType: nil,
                                       amount: sum(unmatched), transactions: unmatched)
            }
        }

        // Largest first, ties by name; the catch-all row always goes last.
        items.sort { $0.amount != $1.amount ? $0.amount > $1.amount
                     : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if let pseudo { items.append(pseudo) }

        let scale = showsPercentages ? total : (items.map(\.amount).max() ?? 0)
        return (items, scale, showsPercentages)
    }

    // MARK: - Trust

    private static func trust(_ input: InsightsInput) -> TrustSummary {
        var summary = TrustSummary()
        var usedAccounts = Set<UUID>()

        for tx in input.transactions where input.current.contains(tx.date) {
            guard !input.filters.excludedAccountIDs.contains(tx.accountID) else { continue }
            usedAccounts.insert(tx.accountID)
            if tx.linkedTransactionID == nil, input.plugCategoryIDs.contains(tx.categoryID) {
                summary.plugTotal += tx.amount
                summary.plugTransactions.append(tx)
            }
        }

        // Same rule as the red traffic light: 30+ days since verified, or never.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: input.now)
        summary.overdueAccountNames = usedAccounts
            .filter { input.activeAccountIDs.contains($0) }
            .filter { id in
                guard let date = input.lastReconciled[id] else { return true }
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? 0
                return days >= 30
            }
            .compactMap { input.accountNames[$0] }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        summary.plugTransactions.sort { $0.date > $1.date }
        return summary
    }
}
