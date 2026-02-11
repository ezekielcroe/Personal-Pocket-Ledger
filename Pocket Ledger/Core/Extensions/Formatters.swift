//
//  Formatters.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 17/1/26.
//


import Foundation

struct Formatters {
    /// Cached formatter for transaction IDs (Internal)
    static let transactionID: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmSSS"
        return formatter
    }()
    
    /// Cached formatter for Section Headers (e.g. "Oct 24, 2025")
    static let sectionHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Cached formatter for Month/Year (e.g. "January 2026")
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}