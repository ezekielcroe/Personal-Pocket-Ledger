//
//  MathParser.swift
//  Pocket Ledger
//  Consolidates the Math engine from three different points
//  Created by Zhi Zheng Yeo on 5/2/26.
//


import Foundation

struct MathParser {
    /// Parses a string input (e.g. "10+2.50") and returns a computed Double.
    /// Handles sanitization, trailing operators, and division-by-zero safety.
    static func calculate(_ input: String) -> Double {
        // 1. Sanitize: Allow only numbers and math operators
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        let sanitized = input.components(separatedBy: allowed.inverted).joined()
        
        // 2. Early exit for empty input
        guard !sanitized.trimmingCharacters(in: .whitespaces).isEmpty else { return 0 }
        
        // 3. Validate: Must contain at least one digit
        let hasDigit = sanitized.contains(where: { $0.isNumber })
        guard hasDigit else { return 0 }
        
        // 4. Recursive Cleanup: Handle trailing operators (e.g., "50+" -> "50")
        let trimmed = sanitized.trimmingCharacters(in: .whitespaces)
        let operators = CharacterSet(charactersIn: "+-*/")
        if let lastChar = trimmed.last,
           operators.contains(Unicode.Scalar(String(lastChar))!) {
            let withoutLast = String(trimmed.dropLast())
            return calculate(withoutLast) // Recursive call
        }
        
        // 5. Evaluate
        // Note: NSExpression does not throw Swift errors, so we removed the do-catch.
        let expression = NSExpression(format: sanitized)
        
        if let result = expression.expressionValue(with: nil, context: nil) as? Double {
            // Guard against Division by Zero (Infinity/NaN)
            guard result.isFinite else { return 0 }
            
            // Round to 2 decimal places
            return (result * 100).rounded() / 100
        } else if let intResult = expression.expressionValue(with: nil, context: nil) as? Int {
            return Double(intResult)
        }
        
        // 6. Fallback
        return Double(sanitized) ?? 0
    }
}
