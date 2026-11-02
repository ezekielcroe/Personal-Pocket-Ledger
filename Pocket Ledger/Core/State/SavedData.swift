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
    var excludeOutliers: Bool = false
    /// Amount range. Optional, so presets saved before these existed
    /// decode as "no limit" (synthesized Codable uses decodeIfPresent).
    var minimumAmount: Decimal? = nil
    var maximumAmount: Decimal? = nil
    /// Breakdown mode and Spending/Income view at save time. Optional, so
    /// older presets keep whatever the page shows. The mode is stored as its
    /// raw string: an unknown value then decodes as nil instead of failing
    /// the whole file.
    var breakdownModeRaw: String? = nil
    var showsIncome: Bool? = nil

    var breakdownMode: BreakdownMode? {
        get { breakdownModeRaw.flatMap(BreakdownMode.init(rawValue:)) }
        set { breakdownModeRaw = newValue?.rawValue }
    }

    /// The preset's filters, in the form Insights uses.
    var filters: InsightFilters {
        get {
            InsightFilters(excludedAccountIDs: excludedAccountIDs,
                           excludedCategoryIDs: excludedCategoryIDs,
                           excludeOutliers: excludeOutliers,
                           minimumAmount: minimumAmount,
                           maximumAmount: maximumAmount)
        }
        set {
            excludedAccountIDs = newValue.excludedAccountIDs
            excludedCategoryIDs = newValue.excludedCategoryIDs
            excludeOutliers = newValue.excludeOutliers
            minimumAmount = newValue.minimumAmount
            maximumAmount = newValue.maximumAmount
        }
    }

    /// True when the preset applies no filters at all.
    var isEmpty: Bool {
        excludedAccountIDs.isEmpty && excludedCategoryIDs.isEmpty &&
        !excludeOutliers && minimumAmount == nil && maximumAmount == nil
    }

    // MARK: - Codable Compatibility
    // Presets saved before the tag system was removed contain an
    // "excludedTagIDs" key; it is ignored on decode and never re-encoded.
    enum CodingKeys: String, CodingKey {
        case id, name, excludedAccountIDs, excludedCategoryIDs, excludeOutliers
        case minimumAmount, maximumAmount
        case breakdownModeRaw = "breakdownMode", showsIncome
    }
}

// MARK: - Remark Bucket

/// A named umbrella over free-text remarks: "Coffee" = ["starbucks",
/// "*bean", "joe's", "#coffee"]. A transaction belongs to the bucket if its
/// remark matches ANY term (see RemarkMatcher for the term syntax). Buckets
/// are queries, not stamps — editing one retroactively re-groups all history.
struct RemarkBucket: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var terms: [String] = []
    
    /// Same rule Insights uses, so a bucket's list and its row always agree.
    func matches(_ remark: String) -> Bool {
        RemarkMatcher.matches(remark, anyOf: RemarkMatcher.parse(terms))
    }
}

// MARK: - Legacy Tag (migration only)

/// Minimal shape of the retired Tag model. Used solely to read old data
/// files so tag names can be folded into transaction remarks on first load.
struct LegacyTag: Codable, Sendable {
    let id: UUID
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
    }
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
    let templates: [TransactionTemplate]
    let insightPresets: [InsightPreset]
    let remarkBuckets: [RemarkBucket]
    
    /// Tags read from files written before the tag system was removed.
    /// Decoded for migration, never written back.
    let legacyTags: [LegacyTag]
    
    init(transactions: [Transaction],
         categories: [Category],
         templates: [TransactionTemplate],
         insightPresets: [InsightPreset],
         remarkBuckets: [RemarkBucket] = [],
         legacyTags: [LegacyTag] = []) {
        self.transactions = transactions
        self.categories = categories
        self.templates = templates
        self.insightPresets = insightPresets
        self.remarkBuckets = remarkBuckets
        self.legacyTags = legacyTags
    }
    
    enum CodingKeys: String, CodingKey {
        case transactions, categories, templates, insightPresets, remarkBuckets
        case legacyTags = "tags"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactions   = try container.decode([Transaction].self, forKey: .transactions)
        categories     = try container.decodeIfPresent([Category].self, forKey: .categories) ?? []
        templates      = try container.decodeIfPresent([TransactionTemplate].self, forKey: .templates) ?? []
        insightPresets = try container.decodeIfPresent([InsightPreset].self, forKey: .insightPresets) ?? []
        remarkBuckets  = try container.decodeIfPresent([RemarkBucket].self, forKey: .remarkBuckets) ?? []
        legacyTags     = try container.decodeIfPresent([LegacyTag].self, forKey: .legacyTags) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(transactions, forKey: .transactions)
        try container.encode(categories, forKey: .categories)
        try container.encode(templates, forKey: .templates)
        try container.encode(insightPresets, forKey: .insightPresets)
        try container.encode(remarkBuckets, forKey: .remarkBuckets)
        // legacyTags intentionally not encoded
    }
}


struct SavedData: Codable, Sendable {
    var accounts: [Account]
    var accountGroups: [AccountGroup]
    var categories: [Category]
    var transactions: [Transaction]
    var templates: [TransactionTemplate]
    var insightPresets: [InsightPreset]
    var remarkBuckets: [RemarkBucket] = []
    
    /// Tags read from backups made before the tag system was removed.
    /// Decoded for migration on import, never written back.
    var legacyTags: [LegacyTag] = []
    
    init(accounts: [Account],
         accountGroups: [AccountGroup],
         categories: [Category],
         transactions: [Transaction],
         templates: [TransactionTemplate],
         insightPresets: [InsightPreset],
         remarkBuckets: [RemarkBucket] = [],
         legacyTags: [LegacyTag] = []) {
        self.accounts = accounts
        self.accountGroups = accountGroups
        self.categories = categories
        self.transactions = transactions
        self.templates = templates
        self.insightPresets = insightPresets
        self.remarkBuckets = remarkBuckets
        self.legacyTags = legacyTags
    }
    
    enum CodingKeys: String, CodingKey {
        case accounts, accountGroups, categories, transactions
        case templates, insightPresets, remarkBuckets
        case legacyTags = "tags"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts       = try container.decode([Account].self, forKey: .accounts)
        accountGroups  = try container.decodeIfPresent([AccountGroup].self, forKey: .accountGroups) ?? []
        categories     = try container.decodeIfPresent([Category].self, forKey: .categories) ?? []
        transactions   = try container.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
        templates      = try container.decodeIfPresent([TransactionTemplate].self, forKey: .templates) ?? []
        insightPresets = try container.decodeIfPresent([InsightPreset].self, forKey: .insightPresets) ?? []
        remarkBuckets  = try container.decodeIfPresent([RemarkBucket].self, forKey: .remarkBuckets) ?? []
        legacyTags     = try container.decodeIfPresent([LegacyTag].self, forKey: .legacyTags) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(accountGroups, forKey: .accountGroups)
        try container.encode(categories, forKey: .categories)
        try container.encode(transactions, forKey: .transactions)
        try container.encode(templates, forKey: .templates)
        try container.encode(insightPresets, forKey: .insightPresets)
        try container.encode(remarkBuckets, forKey: .remarkBuckets)
        // legacyTags intentionally not encoded
    }
}
