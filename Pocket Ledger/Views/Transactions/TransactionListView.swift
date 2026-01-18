import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var data: AppData
    @State private var isPresentingAddSheet = false
    @State private var transactionToEdit: Transaction?

    var body: some View {
        NavigationStack {
            List {
                if data.transactions.isEmpty {
                    Text("No transactions yet. Tap + to add.")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                ForEach(groupedTransactions, id: \.date) { group in
                    Section(header: Text(formatHeaderDate(group.date))) {
                        ForEach(group.transactions) { transaction in
                            NavigationLink {
                                TransactionDetailView(transaction: transaction)
                                    .environmentObject(data)
                            } label: {
                                TransactionRow(transaction: transaction)
                                    .environmentObject(data)
                            }
                            // Swipe Right -> Edit
                            .swipeActions(edge: .leading) {
                                Button {
                                    transactionToEdit = transaction
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            // Swipe Left -> Delete
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteSingleTransaction(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                // Spacer for FAB to ensure bottom items are visible
                Color.clear.frame(height: 80).listRowBackground(Color.clear)
            }
            .navigationTitle("Transactions")
            // Attach the Floating Action Button Modifier
            .floatingAddButton {
                isPresentingAddSheet = true
            }
            .sheet(isPresented: $isPresentingAddSheet) {
                AddTransactionView()
                    .environmentObject(data)
            }
            .sheet(item: $transactionToEdit) { transaction in
                AddTransactionView(editingTransaction: transaction)
                    .environmentObject(data)
            }
        }
    }
    
    // MARK: - Helpers

    struct TransactionGroup {
        let date: Date
        let transactions: [Transaction]
    }

    private var groupedTransactions: [TransactionGroup] {
        let grouped = Dictionary(grouping: data.transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        let sortedDates = grouped.keys.sorted(by: >)
        return sortedDates.map { date in
            let transactions = grouped[date] ?? []
            return TransactionGroup(date: date, transactions: transactions.sorted { $0.date > $1.date })
        }
    }

    private func deleteSingleTransaction(_ transaction: Transaction) {
        if let index = data.transactions.firstIndex(where: { $0.id == transaction.id }) {
            data.transactions.remove(at: index)
            data.save()
        }
    }

    private func formatHeaderDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        else if calendar.isDateInYesterday(date) { return "Yesterday" }
        else {
            return Formatters.sectionHeader.string(from: date)
        }
    }
}
