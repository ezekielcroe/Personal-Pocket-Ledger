//
//  CurrencyFormatter.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 17/1/26.
//

import SwiftUI
import Foundation

struct CurrencyFormatter {
    // We create a reusable formatter to improve performance
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.usesGroupingSeparator = true // Enables "1,000"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()
    
    /// format: 1,234.56
    static func string(from value: Decimal) -> String {
        formatter.currencySymbol = "" // No symbol for raw string
        return formatter.string(from: value as NSDecimalNumber) ?? "0.00"
    }
    
    /// format: $1,234.56 (or user selected symbol)
    static func display(for value: Decimal, with symbol: String) -> String {
        formatter.currencySymbol = symbol
        return formatter.string(from: value as NSDecimalNumber) ?? "\(symbol)0.00"
    }
}

// Optional: A reusable ViewModifier if you want to inject the symbol easily
struct CurrencyDisplay: View {
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    let amount: Decimal
    
    var body: some View {
        // Use the extension we define below
        Text(amount.formattedCurrency(symbol: currencySymbol))
    }
}

// CRITICAL CHANGE: Extension must be on Decimal, not Double
extension Decimal {
    /// Formats the decimal as a currency string with thousand separators (e.g., "$1,234.56")
    func formattedCurrency(symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = symbol
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        // KEY FIX: Decimal bridges to NSDecimalNumber for formatting
        return formatter.string(from: self as NSDecimalNumber) ?? "\(symbol)0.00"
    }
}
