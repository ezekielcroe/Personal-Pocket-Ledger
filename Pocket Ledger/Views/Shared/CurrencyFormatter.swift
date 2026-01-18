//
//  CurrencyFormatter.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 17/1/26.
//


import SwiftUI
import Foundation

struct CurrencyFormatter {
    /// format: 0.00
    static func string(from value: Double) -> String {
        return String(format: "%.2f", value)
    }
    
    /// format: $0.00 (or user selected symbol)
    static func display(for value: Double, with symbol: String) -> String {
        return "\(symbol)\(string(from: value))"
    }
}

// Optional: A reusable ViewModifier if you want to inject the symbol easily
struct CurrencyDisplay: View {
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    let amount: Double
    
    var body: some View {
        Text("\(currencySymbol)\(String(format: "%.2f", amount))")
    }
}

extension Double {
    /// Formats the double as a currency string with thousand separators (e.g., "$1,234.56")
    func formattedCurrency(symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = symbol
        formatter.usesGroupingSeparator = true // Enables "1,000"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: self)) ?? "\(symbol)0.00"
    }
}
