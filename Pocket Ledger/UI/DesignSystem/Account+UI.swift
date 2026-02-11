//
//  Account+UI.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 5/2/26.
// To keep Account.Swift "purely" about data

import SwiftUI

extension AccountType {
    var color: Color {
        switch self {
        case .debit:  return .green
        case .goal:   return .blue
        case .budget: return .purple
        case .debt:   return .orange
        }
    }
}
