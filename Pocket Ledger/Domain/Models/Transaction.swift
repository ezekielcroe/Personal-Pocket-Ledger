import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case inflow
    case outflow
    case transfer
    var id: String { rawValue }
}

struct Transaction: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var linkedTransactionID: UUID?
    var type: TransactionType
    var accountID: UUID
    var categoryID: UUID
    var amount: Decimal
    var date: Date
    var isOutlier: Bool = false
    /// Free-text note: payee, purpose, or anything worth remembering.
    var remark: String = ""
    /// Tag IDs read from files written before the tag system was removed.
    /// Decoded so their names can be migrated into `remark`, never re-encoded.
    var legacyTagIDs: [UUID] = []

    init(
        id: UUID? = nil,
        linkedTransactionID: UUID? = nil,
        type: TransactionType,
        accountID: UUID,
        categoryID: UUID,
        amount: Decimal,
        date: Date = Date(),
        isOutlier: Bool = false,
        remark: String = ""
    ) {
        self.id = id ?? UUID.v7()
        self.linkedTransactionID = linkedTransactionID
        self.type = type
        self.accountID = accountID
        self.categoryID = categoryID
        self.amount = amount
        self.date = date
        self.isOutlier = isOutlier
        self.remark = remark
    }

    // MARK: - Codable Compatibility
    // Custom decoding so books saved before `remark` existed still load.
    enum CodingKeys: String, CodingKey {
        case id, linkedTransactionID, type, accountID, categoryID
        case amount, date, isOutlier, remark
        case legacyTagIDs = "tagIDs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        linkedTransactionID = try container.decodeIfPresent(UUID.self, forKey: .linkedTransactionID)
        type = try container.decode(TransactionType.self, forKey: .type)
        accountID = try container.decode(UUID.self, forKey: .accountID)
        categoryID = try container.decode(UUID.self, forKey: .categoryID)
        amount = try container.decode(Decimal.self, forKey: .amount)
        date = try container.decode(Date.self, forKey: .date)
        isOutlier = try container.decodeIfPresent(Bool.self, forKey: .isOutlier) ?? false
        remark = try container.decodeIfPresent(String.self, forKey: .remark) ?? ""
        legacyTagIDs = try container.decodeIfPresent([UUID].self, forKey: .legacyTagIDs) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(linkedTransactionID, forKey: .linkedTransactionID)
        try container.encode(type, forKey: .type)
        try container.encode(accountID, forKey: .accountID)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encode(amount, forKey: .amount)
        try container.encode(date, forKey: .date)
        try container.encode(isOutlier, forKey: .isOutlier)
        try container.encode(remark, forKey: .remark)
        // legacyTagIDs intentionally not encoded
    }

    // MARK: - Safe ID Generation
    static func generateUniqueTimestampID() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmSSS"
        
        // 1. Generate Timestamp
        let timestamp = formatter.string(from: Date())
        
        // 2. Generate 3 random digits (000-999) to prevent collisions
        // This replaces the unsafe 'static counter'
        let random = Int.random(in: 0...999)
        let randomSuffix = String(format: "%03d", random)
        
        return timestamp + randomSuffix
    }
}
