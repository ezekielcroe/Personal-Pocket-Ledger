//
//  AccountGroup.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 18/1/26.
//

import Foundation

struct AccountGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    /// The IDs of the physical accounts included in this group.
    var accountIDs: [UUID]
    
    init(id: UUID = UUID(), name: String, accountIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.accountIDs = accountIDs
    }
}
