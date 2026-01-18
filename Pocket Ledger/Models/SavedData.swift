//
//  SavedData.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 17/1/26.
//

import Foundation

// MARK: - Insight Preset
struct InsightPreset: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var excludedAccountIDs: Set<UUID> = []
    var excludedCategoryIDs: Set<UUID> = []
    var excludedTagIDs: Set<UUID> = []
    var excludeOutliers: Bool = false
}

// MARK: - SavedData
// Defined here to ensure it is completely independent of the Main Actor
struct SavedData: Codable, Sendable {
    var accounts: [Account]
    // NEW: Account Groups (Optional for backward compatibility)
    // Placed immediately after accounts to match the logical order in AppData
    var accountGroups: [AccountGroup]?
    var categories: [Category]
    var tags: [Tag]
    var transactions: [Transaction]
    var templates: [TransactionTemplate]?
    var reminderTime: DateComponents?
    var insightPresets: [InsightPreset]?
}
