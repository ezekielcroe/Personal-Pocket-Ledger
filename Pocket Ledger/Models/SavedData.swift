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
import Foundation

/// Structure for persisting all user data to disk.
struct SavedData: Codable, Sendable {
    var accounts: [Account]
    var accountGroups: [AccountGroup]?
    var categories: [Category]
    var tags: [Tag]
    var transactions: [Transaction]
    var templates: [TransactionTemplate]?
    var reminderTime: DateComponents?
    var insightPresets: [InsightPreset]?
    
    // MARK: - Migration Support
    
    /// Custom decoder to handle migration from old Account structure
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all fields normally
        self.accountGroups = try container.decodeIfPresent([AccountGroup].self, forKey: .accountGroups)
        self.categories = try container.decode([Category].self, forKey: .categories)
        self.tags = try container.decode([Tag].self, forKey: .tags)
        self.transactions = try container.decode([Transaction].self, forKey: .transactions)
        self.templates = try container.decodeIfPresent([TransactionTemplate].self, forKey: .templates)
        self.reminderTime = try container.decodeIfPresent(DateComponents.self, forKey: .reminderTime)
        self.insightPresets = try container.decodeIfPresent([InsightPreset].self, forKey: .insightPresets)
        
        // Decode accounts with migration logic
        var decodedAccounts = try container.decode([Account].self, forKey: .accounts)
        
        // MIGRATION: Add default values for new fields if they're missing
        for i in 0..<decodedAccounts.count {
            // If account is credit and has no targetAmount, it's a Debt account
            if decodedAccounts[i].isCredit && decodedAccounts[i].targetAmount == nil {
                decodedAccounts[i].targetAmount = nil // Explicitly keep as nil for debt tracking
            }
            
            // targetDate and paymentFrequency will naturally be nil if not present in old data
        }
        
        self.accounts = decodedAccounts
    }
    
    // MARK: - Standard Initializer
    
    init(accounts: [Account],
         accountGroups: [AccountGroup]? = nil,
         categories: [Category],
         tags: [Tag],
         transactions: [Transaction],
         templates: [TransactionTemplate]? = nil,
         reminderTime: DateComponents? = nil,
         insightPresets: [InsightPreset]? = nil) {
        self.accounts = accounts
        self.accountGroups = accountGroups
        self.categories = categories
        self.tags = tags
        self.transactions = transactions
        self.templates = templates
        self.reminderTime = reminderTime
        self.insightPresets = insightPresets
    }
}
