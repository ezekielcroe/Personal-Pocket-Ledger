import SwiftUI

/// Transaction row displaying: emoji | category + tags | amount
struct TransactionRow: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @EnvironmentObject var accountStore: AccountStore
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
                // Primary: Tags (or account name if no tags)
                if !transaction.tagIDs.isEmpty {
                    Text(tagsDisplayString)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if let accName = accountName {
                    Text(accName)
                        .font(.body)
                        .foregroundColor(.primary)
                } else {
                    Text(categoryName)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                // Secondary: Account Type Icon + Account Name + Link Indicator
                HStack(spacing: 4) {
                    if let account = account {
                        AccountTypeIcon(type: account.accountType, size: 14)
                        Text(account.name)
                    }
                    
                    if transaction.linkedTransactionID != nil {
                        Image(systemName: "link")
                            .font(.caption2)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount with Sign (monospaced for alignment)
            HStack(spacing: 2) {
                Text(transaction.type == .inflow ? "+" : "-")
                    .foregroundColor(amountColor)
                
                Text(transaction.amount.formattedCurrency(symbol: currencySymbol))
                    .foregroundColor(amountColor)
            }
            .font(.body.monospacedDigit())
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers
    
    private var account: Account? {
        accountStore.accounts.first(where: { $0.id == transaction.accountID })
    }
    
    private var category: Category? {
        transactionStore.categories.first(where: { $0.id == transaction.categoryID })
    }

    private var categoryName: String {
        category?.name ?? "Uncategorized"
    }
    
    private var categoryEmoji: String {
        category?.emoji ?? "📝"
    }
    
    private var accountName: String? {
        account?.name
    }
    
    /// Builds a comma-separated string of tag names
    private var tagsDisplayString: String {
        let tagNames = transaction.tagIDs.compactMap { tagID in
            transactionStore.tags.first(where: { $0.id == tagID })?.name
        }
        return tagNames.joined(separator: ", ")
    }
    
    // Logic to distinguish Transfers visually
    private var amountColor: Color {
        if categoryName == "Transfer" { return .blue }
        return transaction.type == .inflow ? .green : .red
    }
}
