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
        let trimmed = sanitized.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        
        // 3. Validate: Must contain at least one digit
        guard trimmed.contains(where: { $0.isNumber }) else { return 0 }
        
        // 4. Strip trailing non-digit characters (operators and dots)
        // This handles cases like "50+", "10.", "5+-", etc.
        let trailingJunk = CharacterSet(charactersIn: "+-*/.() ")
        let cleaned = trimmed.trimmingCharacters(in: trailingJunk)
        
        // After cleaning, check we still have content
        guard !cleaned.isEmpty, cleaned.contains(where: { $0.isNumber }) else { return 0 }
        
        // 5. Also strip leading operators (but keep minus for negative numbers)
        let leadingJunk = CharacterSet(charactersIn: "+*/. ")
        var expression = cleaned.trimmingCharacters(in: leadingJunk)
        
        // Handle edge case: expression starts with multiple operators like "--5"
        // Keep at most one leading minus
        while expression.hasPrefix("--") {
            expression = String(expression.dropFirst(2))
        }
        
        guard !expression.isEmpty, expression.contains(where: { $0.isNumber }) else { return 0 }
        
        // 6. Evaluate using NSExpression
        let nsExpression = NSExpression(format: expression)
        
        if let result = nsExpression.expressionValue(with: nil, context: nil) as? Double {
            // Guard against Division by Zero (Infinity/NaN)
            guard result.isFinite else { return 0 }
            // Round to 2 decimal places
            return (result * 100).rounded() / 100
        } else if let intResult = nsExpression.expressionValue(with: nil, context: nil) as? Int {
            return Double(intResult)
        }
        
        // 7. Fallback: Try simple Double parsing
        return Double(expression) ?? 0
    }
}
