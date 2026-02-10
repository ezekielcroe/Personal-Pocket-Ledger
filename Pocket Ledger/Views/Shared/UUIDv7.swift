//
//  UUIDv7.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 10/2/26.
//


import Foundation

extension UUID {
    /// Generates a UUIDv7 (Time-ordered UUID).
    /// This is safer for databases than standard UUID() because it keeps new data together.
    static func v7() -> UUID {
        // 1. Get current timestamp in milliseconds
        let milliseconds = Int64(Date().timeIntervalSince1970 * 1000)
        
        // 2. Create the random bytes (standard UUID v4)
        var uuid = UUID().uuid
        
        // 3. Override the first 48 bits (6 bytes) with the timestamp
        // This puts "Time" at the front of the ID
        uuid.0 = UInt8((milliseconds >> 40) & 0xFF)
        uuid.1 = UInt8((milliseconds >> 32) & 0xFF)
        uuid.2 = UInt8((milliseconds >> 24) & 0xFF)
        uuid.3 = UInt8((milliseconds >> 16) & 0xFF)
        uuid.4 = UInt8((milliseconds >> 8) & 0xFF)
        uuid.5 = UInt8(milliseconds & 0xFF)
        
        // 4. Set version to 7 (0111)
        uuid.6 = (uuid.6 & 0x0F) | 0x70
        
        // 5. Set variant to RFC 4122 (10xx)
        uuid.8 = (uuid.8 & 0x3F) | 0x80
        
        return UUID(uuid: uuid)
    }
}