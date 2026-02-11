//
//  CurrencyFormatter.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 17/1/26.
//

import Foundation

extension Decimal {
    
    // Cache one NumberFormatter per currency symbol.
    // Most users have a single symbol, so this allocates once and reuses forever.
    private static var _formatters: [String: NumberFormatter] = [:]

    /// Formats the decimal as a currency string with thousand separators (e.g., "$1,234.56").
    /// Uses a per-symbol cached NumberFormatter to avoid repeated allocations.
    func formattedCurrency(symbol: String) -> String {
        let formatter: NumberFormatter
        if let cached = Decimal._formatters[symbol] {
            formatter = cached
        } else {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencySymbol = symbol
            f.usesGroupingSeparator = true
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            Decimal._formatters[symbol] = f
            formatter = f
        }
        // Decimal bridges to NSDecimalNumber for formatting.
        return formatter.string(from: self as NSDecimalNumber) ?? "\(symbol)0.00"
    }
}
