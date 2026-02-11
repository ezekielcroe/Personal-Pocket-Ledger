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
    
    /// Formats a date interval into a user-friendly string (e.g., "Jan 1 – Jan 31").
    static func formatInterval(_ interval: DateInterval) -> String {
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            let startYear = calendar.component(.year, from: interval.start)
            
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            
            if startYear == currentYear {
                formatter.dateFormat = "MMM d"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
            }
            
            let startStr = formatter.string(from: interval.start)
            let endStr = formatter.string(from: interval.end)
            
            return "\(startStr) – \(endStr)"
        }
}
