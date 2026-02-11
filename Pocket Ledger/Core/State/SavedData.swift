//
//  SavedData.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 17/1/26.
//

import Foundation

// Keep your InsightPreset here
struct InsightPreset: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var excludedAccountIDs: Set<UUID> = []
    var excludedCategoryIDs: Set<UUID> = []
    var excludedTagIDs: Set<UUID> = []
    var excludeOutliers: Bool = false
}

// NEW: Box for AccountStore
struct SavedAccountData: Codable, Sendable {
    let accounts: [Account]
    let accountGroups: [AccountGroup]
}

// NEW: Box for TransactionStore
struct SavedTransactionData: Codable, Sendable {
    let transactions: [Transaction]
    let categories: [Category]
    let tags: [Tag]
    let templates: [TransactionTemplate]
    let insightPresets: [InsightPreset]
}


struct SavedData: Codable, Sendable {
    var accounts: [Account]
    var accountGroups: [AccountGroup]
    var categories: [Category]
    var tags: [Tag]
    var transactions: [Transaction]
    var templates: [TransactionTemplate]
    var insightPresets: [InsightPreset]
}
