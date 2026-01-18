import SwiftUI

/// Displays all transactions tagged with a specific tag.
struct TagDetailView: View {
    @EnvironmentObject var data: AppData
    var tag: Tag

    var body: some View {
        List {
            Section(header: Text("Transactions")) {
                let tagTransactions = data.transactions(for: tag)
                if tagTransactions.isEmpty {
                    Text("No transactions yet")
                        .foregroundColor(.secondary)
                }
                ForEach(tagTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                        .environmentObject(data)
                }
            }
        }
        .navigationTitle(tag.name)
    }
}