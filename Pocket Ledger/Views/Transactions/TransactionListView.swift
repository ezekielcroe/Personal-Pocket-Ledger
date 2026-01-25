import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var data: AppData
    @State private var isPresentingAddSheet = false
    @State private var transactionToEdit: Transaction?
    
    // Track collapsed dates. Empty set means all are expanded (default state).
    @State private var collapsedDates: Set<Date> = []

    var body: some View {
        NavigationStack {
            List {
                if data.transactions.isEmpty {
                    Text("No transactions yet. Tap + to add.")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                ForEach(groupedTransactions, id: \.date) { group in
                    DisclosureGroup(
                        isExpanded: binding(for: group.date),
                        content: {
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
                        },
                        label: {
                            HStack {
                                Text(formatHeaderDate(group.date))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                // Count badge
                                Text("\(group.transactions.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                            }
                        }
                    )
                }
                
                // Spacer for FAB to ensure bottom items are visible
                Color.clear.frame(height: 80).listRowBackground(Color.clear)
            }
            .navigationTitle("Transactions")
            .toolbar {
                // COLLAPSE/EXPAND ALL BUTTON
                ToolbarItem(placement: .navigationBarLeading) {
                    if !data.transactions.isEmpty {
                        Button {
                            toggleAllSections()
                        } label: {
                            // Icon changes based on whether "All" are currently collapsed
                            let allDates = Set(groupedTransactions.map { $0.date })
                            let allCollapsed = collapsedDates.count == allDates.count && !allDates.isEmpty
                            
                            Image(systemName: allCollapsed ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                                .font(.subheadline)
                        }
                    }
                }
            }
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
    
    // Binding helper for DisclosureGroup
    private func binding(for date: Date) -> Binding<Bool> {
        Binding(
            get: { !collapsedDates.contains(date) },
            set: { isExpanded in
                if isExpanded {
                    collapsedDates.remove(date)
                } else {
                    collapsedDates.insert(date)
                }
            }
        )
    }
    
    private func toggleAllSections() {
        let allDates = Set(groupedTransactions.map { $0.date })
        let allCollapsed = collapsedDates.count == allDates.count
        
        withAnimation {
            if allCollapsed {
                collapsedDates.removeAll() // Expand all
            } else {
                collapsedDates = allDates // Collapse all
            }
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
