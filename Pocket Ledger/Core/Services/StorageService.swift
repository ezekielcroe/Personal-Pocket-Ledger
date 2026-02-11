//
//  StorageService.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 5/2/26.
//

import Foundation

/// A background actor that handles file I/O and JSON serialization.
/// It creates a thread-safe boundary for writing to disk.
actor StorageService {
    
    static let shared = StorageService()
    private let fileManager = FileManager.default
    
    // MARK: - Path Helpers
    
    private func documentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func fileURL(for filename: String) -> URL {
        documentsDirectory().appendingPathComponent(filename)
    }
    
    // MARK: - Generic JSON Saving
    
    /// Encodes any Codable object to JSON and writes it to the Documents directory.
    func save<T: Encodable>(_ object: T, to filename: String) throws {
        let url = fileURL(for: filename)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(object)
        
        // Write atomically to prevent data corruption
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
    
    // MARK: - Generic JSON Loading
    
    /// Reads a file from Documents and decodes it into the requested Type.
    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let url = fileURL(for: filename)
        
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(type, from: data)
    }
    
    // MARK: - File Deletion
    
    /// Deletes a file from the Documents directory. Silently succeeds if the file doesn't exist.
    func delete(filename: String) throws {
        let url = fileURL(for: filename)
        
        // Only attempt deletion if the file actually exists
        guard fileManager.fileExists(atPath: url.path) else { return }
        
        try fileManager.removeItem(at: url)
    }
    
    /// Returns true if a file exists in the Documents directory.
    func fileExists(filename: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: filename).path)
    }
    
    // MARK: - Raw Data Helpers
    
    /// Used for exporting non-JSON data (like CSVs)
    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
    
    /// Used for importing external files (Backups/Imports)
    func readSecureData(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            var coordinatorError: NSError?
            var closureError: Error?
            var result: Data?

            NSFileCoordinator().coordinate(readingItemAt: url, error: &coordinatorError) { safeURL in
                do {
                    result = try Data(contentsOf: safeURL)
                } catch {
                    closureError = error
                }
            }

            if let error = closureError ?? coordinatorError {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: result ?? Data())
            }
        }
    }
    
    enum FileError: Error {
        case fileNotFound
    }
}
