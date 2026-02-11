//
//  BookMetadata.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 18/1/26.
//


import Foundation

/// Represents the lightweight header information for a specific book.
/// This allows the app to list books without loading their full transaction history.
struct BookMetadata: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var created: Date
    var lastOpened: Date
    
    /// Generates a unique filename for this specific book's data.
    var fileName: String {
        "book_\(id.uuidString).json"
    }
    
    init(id: UUID = UUID(), name: String, created: Date = Date(), lastOpened: Date = Date()) {
        self.id = id
        self.name = name
        self.created = created
        self.lastOpened = lastOpened
    }
}

/// The master record stored in 'book_index.json'.
/// It tracks which books exist and which one was used last.
struct BookIndex: Codable, Sendable {
    var books: [BookMetadata]
    var lastActiveBookID: UUID?
}