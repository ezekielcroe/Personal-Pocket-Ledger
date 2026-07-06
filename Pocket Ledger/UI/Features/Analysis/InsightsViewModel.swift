//
//  InsightsViewModel.swift
//  Pocket Ledger
//

import Foundation
import Combine
import SwiftUI

@MainActor
class InsightsViewModel: ObservableObject {
    
    // MARK: - Outputs (The View observes these)
    @Published var stats: AnalyticsStats = .empty
    @Published var previousStats: AnalyticsStats = .empty
    @Published var isLoading: Bool = false
    
    // MARK: - Inputs (View State)
    @Published var timeRange: TimeRange = .thisMonth
    @Published var breakdownMode: BreakdownMode = .category
    @Published var breakdownType: TransactionType = .outflow
    @Published var selectedAnchorDate = Date()
    
    /// Signed offset from the current period. 0 = now, -1 = previous, -2 = two periods back, etc.
    @Published var periodOffset: Int = 0
    
    // MARK: - Filters
    @Published var excludedAccountIDs: Set<UUID> = []
    @Published var excludedCategoryIDs: Set<UUID> = []
    @Published var excludeOutliers: Bool = false
    @Published var minimumAmount: Decimal? = nil
    @Published var maximumAmount: Decimal? = nil
    @Published var selectedPresetID: UUID? = nil

    // MARK: - Current Date Interval (used by InsightsView for detail navigation)

    /// The date interval currently displayed. Exposed so InsightsView can pass
    /// it to detail views (CategoryDetailView) as a filter.
    var currentDateInterval: DateInterval {
        let fiscalStart = UserDefaults.standard.integer(forKey: "fiscalStartDay")
        return timeRange.dateInterval(
            relativeTo: selectedAnchorDate,
            fiscalStartDay: fiscalStart,
            offset: periodOffset
        )
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

    // MARK: - Calculation Logic
    
    /// Triggers a background calculation of the analytics data.
    /// Call this when any input (range, filter, or transaction list) changes.
    func calculate(accountStore: AccountStore, transactionStore: TransactionStore) {
        self.isLoading = true
        
        // 1. Capture data (copy to local variables to safely pass to background task)
        let transactions  = transactionStore.transactions
        let categories    = transactionStore.categories
        let accounts      = accountStore.accounts
        let groups        = accountStore.accountGroups
        let buckets       = transactionStore.remarkBuckets
        
        // 2. Capture configuration
        let currentRange  = self.timeRange
        let currentAnchor = self.selectedAnchorDate
        let currentOffset = self.periodOffset
        let fiscalStart   = UserDefaults.standard.integer(forKey: "fiscalStartDay")
        let mode          = self.breakdownMode
        let type          = self.breakdownType
        
        let filterSettings = FilterSettings(
            excludedAccounts:   excludedAccountIDs,
            excludedCategories: excludedCategoryIDs,
            excludeOutliers:    excludeOutliers,
            min:                minimumAmount,
            max:                maximumAmount
        )
        
        // 3. Run on background thread
        Task.detached(priority: .userInitiated) {
            
            // A. Calculate current period (shifted by periodOffset)
            let currentStats = await self.performCalculation(
                range: currentRange,
                offset: currentOffset,
                anchor: currentAnchor,
                fiscalStart: fiscalStart,
                transactions: transactions,
                categories: categories,
                accounts: accounts,
                groups: groups,
                buckets: buckets,
                filters: filterSettings,
                breakdownMode: mode,
                breakdownType: type
            )
            
            // B. Calculate previous period (one further back for comparison)
            let prevStats = await self.performCalculation(
                range: currentRange,
                offset: currentOffset - 1,
                anchor: currentAnchor,
                fiscalStart: fiscalStart,
                transactions: transactions,
                categories: categories,
                accounts: accounts,
                groups: groups,
                buckets: buckets,
                filters: filterSettings,
                breakdownMode: mode,
                breakdownType: type
            )
            
            // 4. Update UI on main actor
            await MainActor.run {
                self.stats = currentStats
                self.previousStats = prevStats
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Internal Calculation Engine
    
    private struct FilterSettings {
        let excludedAccounts: Set<UUID>
        let excludedCategories: Set<UUID>
        let excludeOutliers: Bool
        let min: Decimal?
        let max: Decimal?
    }
    
    private func performCalculation(
        range: TimeRange,
        offset: Int,
        anchor: Date,
        fiscalStart: Int,
        transactions: [Transaction],
        categories: [Category],
        accounts: [Account],
        groups: [AccountGroup],
        buckets: [RemarkBucket],
        filters: FilterSettings,
        breakdownMode: BreakdownMode,
        breakdownType: TransactionType
    ) -> AnalyticsStats {
        
        let dateInterval = range.dateInterval(relativeTo: anchor, fiscalStartDay: fiscalStart, offset: offset)
        
        // Lookup sets for logic
        let transferCategoryIDs = Set(categories.filter { $0.name == "Transfer" }.map { $0.id })
        let pureDebtAccountIDs  = Set(accounts.filter { $0.accountType == .debt }.map { $0.id })
        
        // 1. Filter transactions
        let filtered = Self.applyFilters(transactions, interval: dateInterval, filters: filters)
        
        // 2. Calculate global totals (smart transfer logic)
        var income: Decimal = 0
        var expense: Decimal = 0
        
        for tx in filtered {
            let isTransferCategory = transferCategoryIDs.contains(tx.categoryID)
            
            if isTransferCategory {
                // Only transfers TO pure debt accounts count as expense (loan payment)
                if tx.type == .inflow && pureDebtAccountIDs.contains(tx.accountID) {
                    if let linkedID = tx.linkedTransactionID,
                       let linkedTx = transactions.first(where: { $0.id == linkedID }) {
                        if !pureDebtAccountIDs.contains(linkedTx.accountID) {
                            expense += tx.amount
                        }
                    }
                }
            } else {
                if tx.type == .inflow       { income  += tx.amount }
                else if tx.type == .outflow { expense += tx.amount }
            }
        }
        
        // 3. Generate breakdown
        let breakdownTransactions = Self.breakdownEligible(
            filtered,
            allTransactions: transactions,
            transferCategoryIDs: transferCategoryIDs,
            pureDebtAccountIDs: pureDebtAccountIDs,
            breakdownType: breakdownType
        )
        
        let breakdownTotal = breakdownTransactions.reduce(0) { $0 + $1.amount }
        var breakdownItems: [AnalyticsItem] = []
        
        switch breakdownMode {
        case .category:
            var dict: [UUID: Decimal] = [:]
            for tx in breakdownTransactions { dict[tx.categoryID, default: 0] += tx.amount }
            
            breakdownItems = dict.compactMap { (id, amount) in
                guard let cat = categories.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: cat.name, icon: cat.emoji, amount: amount, color: .primary)
            }
            
        case .account:
            var dict: [UUID: Decimal] = [:]
            for tx in breakdownTransactions { dict[tx.accountID, default: 0] += tx.amount }
            
            breakdownItems = dict.compactMap { (id, amount) in
                guard let acc = accounts.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: acc.name, icon: acc.accountType.icon, amount: amount, color: acc.accountType.color)
            }
            
        case .group:
            var ungroupedAmount: Decimal = 0
            var accountToGroupMap: [UUID: UUID] = [:]
            
            for group in groups {
                let memberAccountIDs = group.allAccountIDs(in: groups, accounts: accounts)
                for accountID in memberAccountIDs {
                    accountToGroupMap[accountID] = group.id
                }
            }
            
            var dict: [UUID: Decimal] = [:]
            
            for tx in breakdownTransactions {
                if let groupID = accountToGroupMap[tx.accountID] {
                    dict[groupID, default: 0] += tx.amount
                } else {
                    ungroupedAmount += tx.amount
                }
            }
            
            breakdownItems = dict.compactMap { (id, amount) in
                guard let group = groups.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: group.name, icon: "folder.fill", amount: amount, color: .purple)
            }
            
            if ungroupedAmount > 0 {
                breakdownItems.append(AnalyticsItem(id: UUID(), name: "Ungrouped", icon: "building.columns", amount: ungroupedAmount, color: .secondary))
            }
            
        case .bucket:
            // Buckets overlap: one transaction can feed several buckets, so
            // amounts are absolute totals, not shares of a whole.
            var unmatchedAmount: Decimal = 0
            var dict: [UUID: Decimal] = [:]
            
            for tx in breakdownTransactions {
                var matchedAny = false
                for bucket in buckets where bucket.matches(tx.remark) {
                    dict[bucket.id, default: 0] += tx.amount
                    matchedAny = true
                }
                if !matchedAny { unmatchedAmount += tx.amount }
            }
            
            breakdownItems = dict.compactMap { (id, amount) in
                guard let bucket = buckets.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: bucket.name, icon: "text.magnifyingglass", amount: amount, color: .teal)
            }
            
            if unmatchedAmount > 0 {
                breakdownItems.append(AnalyticsItem(id: UUID(), name: "Unmatched", icon: "questionmark.circle", amount: unmatchedAmount, color: .secondary))
            }
        }
        
        // Bucket amounts overlap, so a shared denominator would lie; the
        // largest bucket sets the bar scale instead.
        let totalForBars: Decimal = (breakdownMode == .bucket)
            ? (breakdownItems.map { $0.amount }.max() ?? 0)
            : breakdownTotal
        
        return AnalyticsStats(
            income: income,
            expense: expense,
            breakdownItems: breakdownItems.sorted { $0.amount > $1.amount },
            totalForBreakdown: totalForBars
        )
    }

    
    // =========================================================
    // MARK: - Shared Pipeline Helpers
    // =========================================================
    
    /// Step 1 of the pipeline: date window + user filters.
    nonisolated private static func applyFilters(
        _ transactions: [Transaction],
        interval: DateInterval,
        filters: FilterSettings
    ) -> [Transaction] {
        transactions.filter { tx in
            if !interval.contains(tx.date)                          { return false }
            if filters.excludeOutliers && tx.isOutlier              { return false }
            if filters.excludedAccounts.contains(tx.accountID)      { return false }
            if filters.excludedCategories.contains(tx.categoryID)   { return false }
            if let min = filters.min, tx.amount < min               { return false }
            if let max = filters.max, tx.amount > max               { return false }
            return true
        }
    }
    
    /// Step 3 of the pipeline: which transactions count toward the breakdown,
    /// honoring the inflow/outflow toggle and the debt-payment transfer rule.
    nonisolated private static func breakdownEligible(
        _ filtered: [Transaction],
        allTransactions: [Transaction],
        transferCategoryIDs: Set<UUID>,
        pureDebtAccountIDs: Set<UUID>,
        breakdownType: TransactionType
    ) -> [Transaction] {
        var result: [Transaction] = []
        for tx in filtered {
            let isTransferCategory = transferCategoryIDs.contains(tx.categoryID)
            
            if breakdownType == .outflow {
                // Include: regular outflows + transfers TO pure debt accounts
                if tx.type == .outflow && !isTransferCategory {
                    result.append(tx)
                } else if isTransferCategory && tx.type == .inflow && pureDebtAccountIDs.contains(tx.accountID) {
                    if let linkedID = tx.linkedTransactionID,
                       let linkedTx = allTransactions.first(where: { $0.id == linkedID }) {
                        if !pureDebtAccountIDs.contains(linkedTx.accountID) {
                            result.append(tx)
                        }
                    }
                }
            } else {
                // Income: regular inflows only
                if tx.type == .inflow && !isTransferCategory {
                    result.append(tx)
                }
            }
        }
        return result
    }
    
    
    // =========================================================
    // MARK: - Ad-hoc Remark Stats
    // =========================================================
    
    /// Totals, count, average, and a per-period trend for transactions whose
    /// remark contains ANY of `terms` (case-insensitive). An EMPTY term list
    /// matches every transaction — used for the page-level trend. Uses the
    /// currently selected period, filters, and inflow/outflow toggle, so the
    /// numbers line up with everything else on the Insights page.
    func remarkStats(
        terms: [String],
        transactionStore: TransactionStore,
        accountStore: AccountStore,
        trendPeriods: Int = 6
    ) -> RemarkTermStats {
        let cleaned = terms
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        
        func matches(_ tx: Transaction) -> Bool {
            if cleaned.isEmpty { return true } // no terms = whole-page stats
            guard !tx.remark.isEmpty else { return false }
            let lower = tx.remark.lowercased()
            return cleaned.contains { lower.contains($0) }
        }
        
        let transactions = transactionStore.transactions
        let categories   = transactionStore.categories
        let accounts     = accountStore.accounts
        
        let transferCategoryIDs = Set(categories.filter { $0.name == "Transfer" }.map { $0.id })
        let pureDebtAccountIDs  = Set(accounts.filter { $0.accountType == .debt }.map { $0.id })
        
        let filters = FilterSettings(
            excludedAccounts:   excludedAccountIDs,
            excludedCategories: excludedCategoryIDs,
            excludeOutliers:    excludeOutliers,
            min:                minimumAmount,
            max:                maximumAmount
        )
        
        func amountAndCount(in interval: DateInterval) -> (Decimal, Int) {
            let filtered = Self.applyFilters(transactions, interval: interval, filters: filters)
            let eligible = Self.breakdownEligible(
                filtered,
                allTransactions: transactions,
                transferCategoryIDs: transferCategoryIDs,
                pureDebtAccountIDs: pureDebtAccountIDs,
                breakdownType: breakdownType
            )
            let matching = eligible.filter(matches)
            return (matching.reduce(0) { $0 + $1.amount }, matching.count)
        }
        
        // Current period
        let (total, count) = amountAndCount(in: currentDateInterval)
        let average: Decimal = count > 0 ? total / Decimal(count) : 0
        
        // Trend: the last `trendPeriods` periods ending at the one on screen.
        // "All Time" has no period size, so it falls back to calendar months.
        let fiscalStart = UserDefaults.standard.integer(forKey: "fiscalStartDay")
        let calendar = Calendar.current
        var trend: [TrendPoint] = []
        
        let labelFormatter = DateFormatter()
        switch timeRange {
        case .thisWeek:            labelFormatter.dateFormat = "d MMM"
        case .thisMonth, .allTime: labelFormatter.dateFormat = "MMM"
        case .thisYear:            labelFormatter.dateFormat = "yyyy"
        }
        
        if timeRange == .allTime {
            for back in stride(from: trendPeriods - 1, through: 0, by: -1) {
                guard let monthAnchor = calendar.date(byAdding: .month, value: -back, to: Date()),
                      let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { continue }
                let (amount, _) = amountAndCount(in: interval)
                trend.append(TrendPoint(label: labelFormatter.string(from: interval.start), amount: amount))
            }
        } else {
            for back in stride(from: trendPeriods - 1, through: 0, by: -1) {
                let interval = timeRange.dateInterval(
                    relativeTo: selectedAnchorDate,
                    fiscalStartDay: fiscalStart,
                    offset: periodOffset - back
                )
                let (amount, _) = amountAndCount(in: interval)
                trend.append(TrendPoint(label: labelFormatter.string(from: interval.start), amount: amount))
            }
        }
        
        return RemarkTermStats(total: total, count: count, average: average, trend: trend)
    }
}

// MARK: - Supporting Data Structures

struct AnalyticsStats {
    var income: Decimal
    var expense: Decimal
    var net: Decimal { income - expense }
    var breakdownItems: [AnalyticsItem]
    var totalForBreakdown: Decimal
    
    static let empty = AnalyticsStats(income: 0, expense: 0, breakdownItems: [], totalForBreakdown: 0)
}

struct AnalyticsItem: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let amount: Decimal
    let color: Color?
}



// MARK: - Remark Stats Types

struct RemarkTermStats {
    let total: Decimal
    let count: Int
    let average: Decimal
    let trend: [TrendPoint]
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let label: String
    let amount: Decimal
}
