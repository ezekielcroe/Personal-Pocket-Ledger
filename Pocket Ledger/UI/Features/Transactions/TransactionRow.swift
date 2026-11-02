import SwiftUI

/// Transaction row displaying: emoji | remark or account | amount
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
                // Primary: Remark (or account name, or category if neither)
                if !transaction.remark.isEmpty {
                    RemarkText.styled(transaction.remark)
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
    
    // Logic to distinguish Transfers visually
    private var amountColor: Color {
        // A transfer is identified by its link to a partner leg, not by name.
        if transaction.linkedTransactionID != nil { return .blue }
        return transaction.type == .inflow ? .green : .red
    }
}

// MARK: - Remark Text

/// A remark with its #tags shown in the accent colour, so the "why" stands
/// out from the "who" ("Dinner at Lolla #datenight").
enum RemarkText {
    static func styled(_ remark: String) -> Text {
        RemarkMatcher.segments(of: remark).reduce(Text(verbatim: "")) { text, segment in
            let part = segment.isTag
                ? Text(verbatim: segment.text).foregroundColor(.accentColor).fontWeight(.medium)
                : Text(verbatim: segment.text)
            return Text("\(text)\(part)")
        }
    }
}
