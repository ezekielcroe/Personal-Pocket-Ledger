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
    var tagIDs: [UUID]
    var amount: Decimal
    var date: Date
    var isOutlier: Bool = false

    init(
        id: UUID? = nil,
        linkedTransactionID: UUID? = nil,
        type: TransactionType,
        accountID: UUID,
        categoryID: UUID,
        tagIDs: [UUID] = [],
        amount: Decimal,
        date: Date = Date(),
        isOutlier: Bool = false
    ) {
        self.id = id ?? UUID.v7()
        self.linkedTransactionID = linkedTransactionID
        self.type = type
        self.accountID = accountID
        self.categoryID = categoryID
        self.tagIDs = tagIDs
        self.amount = amount
        self.date = date
        self.isOutlier = isOutlier
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
