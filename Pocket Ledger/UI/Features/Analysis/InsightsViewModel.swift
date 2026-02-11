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
    
    // MARK: - Filters
    @Published var excludedAccountIDs: Set<UUID> = []
    @Published var excludedCategoryIDs: Set<UUID> = []
    @Published var excludedTagIDs: Set<UUID> = []
    @Published var excludeOutliers: Bool = false
    @Published var minimumAmount: Decimal? = nil
    @Published var maximumAmount: Decimal? = nil
    @Published var selectedPresetID: UUID? = nil

    // MARK: - Current Date Interval (used by InsightsView for detail navigation)

    /// The date interval currently displayed. Exposed so InsightsView can pass
    /// it to detail views (CategoryDetailView, TagDetailView) as a filter.
    var currentDateInterval: DateInterval {
        let fiscalStart = UserDefaults.standard.integer(forKey: "fiscalStartDay")
        return timeRange.dateInterval(
            relativeTo: selectedAnchorDate,
            fiscalStartDay: fiscalStart,
            offset: 0
        )
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
        let tags          = transactionStore.tags
        
        // 2. Capture configuration
        let currentRange  = self.timeRange
        let currentAnchor = self.selectedAnchorDate
        let fiscalStart   = UserDefaults.standard.integer(forKey: "fiscalStartDay")
        let mode          = self.breakdownMode
        let type          = self.breakdownType
        
        let filterSettings = FilterSettings(
            excludedAccounts:   excludedAccountIDs,
            excludedCategories: excludedCategoryIDs,
            excludedTags:       excludedTagIDs,
            excludeOutliers:    excludeOutliers,
            min:                minimumAmount,
            max:                maximumAmount
        )
        
        // 3. Run on background thread
        Task.detached(priority: .userInitiated) {
            
            // A. Calculate current period
            let currentStats = await self.performCalculation(
                range: currentRange,
                offset: 0,
                anchor: currentAnchor,
                fiscalStart: fiscalStart,
                transactions: transactions,
                categories: categories,
                accounts: accounts,
                groups: groups,
                tags: tags,
                filters: filterSettings,
                breakdownMode: mode,
                breakdownType: type
            )
            
            // B. Calculate previous period (for comparison)
            let prevStats = await self.performCalculation(
                range: currentRange,
                offset: -1,
                anchor: currentAnchor,
                fiscalStart: fiscalStart,
                transactions: transactions,
                categories: categories,
                accounts: accounts,
                groups: groups,
                tags: tags,
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
        let excludedTags: Set<UUID>
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
        tags: [Tag],
        filters: FilterSettings,
        breakdownMode: BreakdownMode,
        breakdownType: TransactionType
    ) -> AnalyticsStats {
        
        let dateInterval = range.dateInterval(relativeTo: anchor, fiscalStartDay: fiscalStart, offset: offset)
        
        // Lookup sets for logic
        let transferCategoryIDs = Set(categories.filter { $0.name == "Transfer" }.map { $0.id })
        let pureDebtAccountIDs  = Set(accounts.filter { $0.accountType == .debt }.map { $0.id })
        
        // 1. Filter transactions
        let filtered = transactions.filter { tx in
            let date = tx.date
            
            if !dateInterval.contains(date)                                                  { return false }
            if filters.excludeOutliers && tx.isOutlier                                      { return false }
            if filters.excludedAccounts.contains(tx.accountID)                              { return false }
            if filters.excludedCategories.contains(tx.categoryID)                           { return false }
            if !tx.tagIDs.isEmpty && !Set(tx.tagIDs).isDisjoint(with: filters.excludedTags) { return false }
            if let min = filters.min, tx.amount < min                                       { return false }
            if let max = filters.max, tx.amount > max                                       { return false }
            
            return true
        }
        
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
        var breakdownTransactions: [Transaction] = []
        
        for tx in filtered {
            let isTransferCategory = transferCategoryIDs.contains(tx.categoryID)
            
            if breakdownType == .outflow {
                // Include: regular outflows + transfers TO pure debt accounts
                if tx.type == .outflow && !isTransferCategory {
                    breakdownTransactions.append(tx)
                } else if isTransferCategory && tx.type == .inflow && pureDebtAccountIDs.contains(tx.accountID) {
                    if let linkedID = tx.linkedTransactionID,
                       let linkedTx = transactions.first(where: { $0.id == linkedID }) {
                        if !pureDebtAccountIDs.contains(linkedTx.accountID) {
                            breakdownTransactions.append(tx)
                        }
                    }
                }
            } else {
                // Income: regular inflows only
                if tx.type == .inflow && !isTransferCategory {
                    breakdownTransactions.append(tx)
                }
            }
        }
        
        let breakdownTotal = breakdownTransactions.reduce(0) { $0 + $1.amount }
        var breakdownItems: [AnalyticsItem] = []
        
        switch breakdownMode {
        case .category:
            var dict: [UUID: Decimal] = [:]
            for tx in breakdownTransactions { dict[tx.categoryID, default: 0] += tx.amount }
            
            breakdownItems = dict.compactMap { (id, amount) in
                guard let cat = categories.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: cat.name, icon: cat.emoji, amount: amount, color: nil)
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
            
        case .tag:
            var untaggedAmount: Decimal = 0
            var dict: [UUID: Decimal] = [:]
            
            for tx in breakdownTransactions {
                if tx.tagIDs.isEmpty {
                    untaggedAmount += tx.amount
                } else {
                    for tagID in tx.tagIDs {
                        dict[tagID, default: 0] += tx.amount
                    }
                }
            }
            
            breakdownItems = dict.compactMap { (id, amount) in
                guard let tag = tags.first(where: { $0.id == id }) else { return nil }
                return AnalyticsItem(id: id, name: tag.name, icon: "tag.fill", amount: amount, color: .blue)
            }
            
            if untaggedAmount > 0 {
                breakdownItems.append(AnalyticsItem(id: UUID(), name: "No Tag", icon: "tag.slash", amount: untaggedAmount, color: .secondary))
            }
        }
        
        return AnalyticsStats(
            income: income,
            expense: expense,
            breakdownItems: breakdownItems.sorted { $0.amount > $1.amount },
            totalForBreakdown: breakdownTotal
        )
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
