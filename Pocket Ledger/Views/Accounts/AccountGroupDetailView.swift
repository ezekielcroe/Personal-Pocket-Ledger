//
//  AccountGroupDetailView.swift
//  Pocket Ledger
//
//  Created by Zhi Zheng Yeo on 18/1/26.
//


import SwiftUI

struct AccountGroupDetailView: View {
    @EnvironmentObject var data: AppData
    let group: AccountGroup
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    @AppStorage("fiscalStartDay") private var fiscalStartDay: Int = 1
    
    var body: some View {
        List {
            Section(header: Text("Balance")) {
                HStack {
                    Text("Total Group Balance")
                    Spacer()
                    Text(data.balance(for: group).formattedCurrency(symbol: currencySymbol))
                        .fontWeight(.bold)
                }
            }
            
            // Statistics parity with physical accounts
            Section(header: Text("Statistics")) {
                let totals = calculateGroupMonthlyTotals()
                StatRow(title: "Inflow (This Month)", value: totals.inflow, symbol: currencySymbol, color: .green)
                StatRow(title: "Outflow (This Month)", value: totals.outflow, symbol: currencySymbol, color: .red)
            }
            
            Section(header: Text("Breakdown")) {
                ForEach(group.accountIDs, id: \.self) { id in
                    if let acc = data.accounts.first(where: { $0.id == id }) {
                        HStack {
                            Text(acc.name)
                            Spacer()
                            Text(data.balance(for: acc).formattedCurrency(symbol: currencySymbol))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("Recent Activity")) {
                let recent = data.transactions
                    .filter { group.accountIDs.contains($0.accountID) }
                    .sorted { $0.date > $1.date }
                    .prefix(50)
                
                if recent.isEmpty {
                    Text("No transactions in this group.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(recent) { tx in
                        NavigationLink(destination: TransactionDetailView(transaction: tx)) {
                            TransactionRow(transaction: tx)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
    }
    
    private func calculateGroupMonthlyTotals() -> (inflow: Double, outflow: Double) {
        let transactions = data.transactions.filter { group.accountIDs.contains($0.accountID) }
        let range = getCurrentFiscalRange()
        let filtered = transactions.filter { $0.date >= range.start && $0.date <= range.end }
        
        let inflow = filtered.filter { $0.type == .inflow }.reduce(0) { $0 + $1.amount }
        let outflow = filtered.filter { $0.type == .outflow }.reduce(0) { $0 + $1.amount }
        return (inflow, outflow)
    }

    private func getCurrentFiscalRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startComp = DateComponents(year: components.year, month: components.month, day: fiscalStartDay)
        var start = calendar.date(from: startComp) ?? Date()
        if Date() < start { start = calendar.date(byAdding: .month, value: -1, to: start) ?? start }
        let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? Date()
        return (start, end)
    }
}
