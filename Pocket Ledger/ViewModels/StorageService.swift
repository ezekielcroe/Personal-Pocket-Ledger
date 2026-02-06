//
//  StorageService.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 5/2/26.
//

import Foundation

/// A background actor that handles ONLY raw file I/O.
/// It knows nothing about AppData models to avoid concurrency conflicts.
actor StorageService {
    
    // MARK: - Generic Write
    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
    
    // MARK: - Generic Read
    func read(from url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }
    
    // MARK: - Import Security
    func readSecureData(from url: URL) throws -> Data {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "Permissions", code: 403, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try Data(contentsOf: url)
    }
}
