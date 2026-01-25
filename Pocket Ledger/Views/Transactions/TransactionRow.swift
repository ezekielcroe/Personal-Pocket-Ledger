import SwiftUI

/// Enhanced transaction row with category emoji and account type icon
struct TransactionRow: View {
    @EnvironmentObject var data: AppData
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"
    var transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // VISUAL: Category Emoji (larger, prominent)
            Text(categoryEmoji)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                // Primary: Category Name
                Text(categoryName)
                    .font(.body)
                    .foregroundColor(.primary)
                
                // Secondary: Account Type Icon + Account Name
                HStack(spacing: 4) {
                    // VISUAL: Account Type Icon (compact)
                    if let account = account {
                        AccountTypeIcon(type: account.accountType, size: 14)
                    }
                    
                    if let accName = accountName {
                        Text(accName)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                // Amount with Sign
                HStack(spacing: 2) {
                    Text(transaction.type == .inflow ? "+" : "-")
                        .foregroundColor(amountColor)
                    
                    Text(transaction.amount.formattedCurrency(symbol: currencySymbol))
                        .monospacedDigit()
                        .foregroundColor(amountColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers
    
    private var account: Account? {
        data.accounts.first(where: { $0.id == transaction.accountID })
    }
    
    private var category: Category? {
        data.categories.first(where: { $0.id == transaction.categoryID })
    }

    private var categoryName: String {
        category?.name ?? "Uncategorized"
    }
    
    private var categoryEmoji: String {
        category?.emoji ?? "❓"
    }
    
    private var accountName: String? {
        account?.name
    }
    
    // Logic to distinguish Transfers visually
    private var amountColor: Color {
        if categoryName == "Transfer" { return .blue }
        return transaction.type == .inflow ? .green : .red
    }
}
