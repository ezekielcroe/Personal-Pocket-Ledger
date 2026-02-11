//
//  Account+UI.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 5/2/26.


import SwiftUI

extension AccountType {

    /// SF Symbol icon for each account type
    var icon: String {
        switch self {
        case .debit:  return "banknote"
        case .goal:   return "lock.fill"
        case .limit:  return "creditcard.fill"
        case .debt:   return "minus.circle.fill"
        }
    }

    /// Section header name used for grouping in lists
    var sectionName: String {
        self.rawValue
    }

    var color: Color {
        switch self {
        case .debit:  return .green
        case .goal:   return .blue
        case .limit:  return .purple
        case .debt:   return .orange
        }
    }
}
