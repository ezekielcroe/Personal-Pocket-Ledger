//
//  RemarkTrendChart.swift
//  Pocket Ledger
//
//  Created by Yeo Zhi Zheng on 6/7/26.
//


//
//  BucketsView.swift
//  Pocket Ledger
//
//  Remark buckets: named umbrellas over free-text remarks.
//  Contains the management list, the editor, the per-bucket detail view,
//  and the shared trend chart used here and in the Insights lookup panel.
//

import SwiftUI
import Charts

// MARK: - Trend Chart

/// A small bar chart of per-period amounts. Bars are absolute values;
/// the y-axis is hidden to keep it glanceable.
struct RemarkTrendChart: View {
    let points: [TrendPoint]
    let currencySymbol: String

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Period", point.label),
                y: .value("Amount", NSDecimalNumber(decimal: point.amount).doubleValue)
            )
            .foregroundStyle(Color.teal.gradient)
            .cornerRadius(3)
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Manage Buckets

struct ManageBucketsView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @State private var showingAddSheet = false

    var body: some View {
        List {
            if transactionStore.remarkBuckets.isEmpty {
                Section(footer: Text("A bucket groups remarks under one name. \"Coffee\" with the terms starbucks, coffeebean, and joe's counts every transaction whose remark contains any of them.")) {
                    Text("No buckets yet")
                        .foregroundColor(.secondary)
                }
            } else {
                Section(footer: Text("A transaction counts toward a bucket if its remark contains any of the bucket's terms. One transaction can fall into several buckets.")) {
                    ForEach(sortedBuckets) { bucket in
                        NavigationLink(destination: EditBucketView(bucket: bucket)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bucket.name)
                                    .font(.body)
                                Text(bucket.terms.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .onDelete(perform: deleteBuckets)
                }
            }
        }
        .navigationTitle("Remark Buckets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                EditBucketView(bucket: nil)
            }
        }
    }

    private var sortedBuckets: [RemarkBucket] {
        transactionStore.remarkBuckets
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func deleteBuckets(at offsets: IndexSet) {
        let targets = offsets.map { sortedBuckets[$0] }
        for bucket in targets {
            transactionStore.deleteBucket(bucket)
        }
    }
}

// MARK: - Edit / Create Bucket

struct EditBucketView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @Environment(\.dismiss) var dismiss

    /// nil = creating a new bucket.
    let bucket: RemarkBucket?

    @State private var name: String = ""
    @State private var terms: [String] = []
    @State private var newTerm: String = ""
    @FocusState private var isTermFieldFocused: Bool

    init(bucket: RemarkBucket?) {
        self.bucket = bucket
        _name = State(initialValue: bucket?.name ?? "")
        _terms = State(initialValue: bucket?.terms ?? [])
    }

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField("e.g. Coffee", text: $name)
            }

            Section(header: Text("Terms"),
                    footer: Text("A transaction matches if its remark contains any term (not case-sensitive).")) {
                ForEach(terms, id: \.self) { term in
                    Text(term)
                }
                .onDelete { offsets in
                    terms.remove(atOffsets: offsets)
                }

                HStack {
                    TextField("Add a term...", text: $newTerm)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isTermFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { addTerm(newTerm) }
                    if !newTerm.isEmpty {
                        Button {
                            addTerm(newTerm)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }

                // Suggestions from words you've already used in remarks
                if isTermFieldFocused {
                    ForEach(termSuggestions, id: \.self) { suggestion in
                        Button {
                            addTerm(suggestion)
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(suggestion)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(bucket == nil ? "New Bucket" : "Edit Bucket")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
    }

    private var termSuggestions: [String] {
        transactionStore.remarkWordSuggestions(completing: newTerm)
            .map { $0.lowercased() }
            .filter { candidate in
                !terms.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
            }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !terms.isEmpty
    }

    private func addTerm(_ raw: String) {
        let term = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return }
        guard !terms.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) else {
            newTerm = ""
            return
        }
        terms.append(term)
        newTerm = ""
        isTermFieldFocused = true
    }

    private func save() {
        var updated = bucket ?? RemarkBucket(name: "", terms: [])
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.terms = terms
        transactionStore.saveBucket(updated)
        dismiss()
    }
}

// MARK: - Bucket Detail

/// All transactions matching a bucket within the period selected on the
/// Insights page, plus a six-month spending trend for the bucket.
struct BucketDetailView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @EnvironmentObject var accountStore: AccountStore
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"

    let bucket: RemarkBucket
    let dateFilter: DateInterval

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    summaryStat(label: "Spent", value: outflowTotal.formattedCurrency(symbol: currencySymbol))
                    summaryStat(label: "Received", value: inflowTotal.formattedCurrency(symbol: currencySymbol))
                    summaryStat(label: "Count", value: "\(matchingTransactions.count)")
                }
                .padding(.vertical, 4)

                RemarkTrendChart(points: monthlyTrend, currencySymbol: currencySymbol)
                    .frame(height: 120)
                    .padding(.vertical, 4)
            } header: {
                Text("Last 6 Months")
            } footer: {
                Text("Terms: \(bucket.terms.joined(separator: ", "))")
            }

            Section(header: Text("Matching Transactions")) {
                if matchingTransactions.isEmpty {
                    Text("No matches in this period")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(matchingTransactions) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
        }
        .navigationTitle(bucket.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Data

    /// Matches within the period passed in from the Insights page.
    private var matchingTransactions: [Transaction] {
        transactionStore.transactions
            .filter { dateFilter.contains($0.date) && bucket.matches($0.remark) }
            .sorted { $0.date > $1.date }
    }

    private var outflowTotal: Decimal {
        matchingTransactions.filter { $0.type == .outflow }.reduce(0) { $0 + $1.amount }
    }

    private var inflowTotal: Decimal {
        matchingTransactions.filter { $0.type == .inflow }.reduce(0) { $0 + $1.amount }
    }

    /// Outflow totals per calendar month for the trailing six months,
    /// independent of the period filter above.
    private var monthlyTrend: [TrendPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var points: [TrendPoint] = []
        for back in stride(from: 5, through: 0, by: -1) {
            guard let anchor = calendar.date(byAdding: .month, value: -back, to: Date()),
                  let interval = calendar.dateInterval(of: .month, for: anchor) else { continue }
            let amount = transactionStore.transactions
                .filter { $0.type == .outflow && interval.contains($0.date) && bucket.matches($0.remark) }
                .reduce(Decimal(0)) { $0 + $1.amount }
            points.append(TrendPoint(label: formatter.string(from: interval.start), amount: amount))
        }
        return points
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}