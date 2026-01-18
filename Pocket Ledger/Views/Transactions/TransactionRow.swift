import SwiftUI

/// A simple row for displaying a transaction in a list.
struct TransactionRow: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    var transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Primary: Category Name
                Text(categoryName)
                    .font(.body)
                    .foregroundColor(.primary)
                
                // Secondary: Account Name • First Tag
                HStack(spacing: 4) {
                    if let accName = accountName {
                        Text(accName)
                    }
                    
                    if let tagName = firstTagName {
                        Text("•")
                        Text(tagName)
                            .fontWeight(.medium)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount and Sign
            // We don't show + / - for transfers to keep it clean, or we can keep it strict.
            // Here I keep strict logic: Outflow (-), Inflow (+)
            Text(transaction.type == .inflow ? "+" : "-")
                .foregroundColor(amountColor)
            
            // NEW: Use the helper for commas
            Text(transaction.amount.formattedCurrency(symbol: currencySymbol))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var categoryName: String {
        let id = transaction.categoryID
        if let category = data.categories.first(where: { $0.id == id }) {
            return category.name
        }
        return "Uncategorized"
    }
    
    private var accountName: String? {
        data.accounts.first(where: { $0.id == transaction.accountID })?.name
    }
    
    private var firstTagName: String? {
        guard let firstTagID = transaction.tagIDs.first else { return nil }
        return data.tags.first(where: { $0.id == firstTagID })?.name
    }
    
    // Logic to distinguish Transfers visually
    private var amountColor: Color {
        if categoryName == "Transfer" { return .blue }
        return transaction.type == .inflow ? .green : .red
    }
}
