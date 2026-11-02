//
//  InsightDrillDownView.swift
//  Pocket Ledger
//
//  The transactions behind any number on the Insights page. The list comes
//  straight from InsightsEngine — the same transactions that produced the
//  number you tapped — so the total here always matches the row.
//

import SwiftUI

struct InsightDrillDownView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var transactionStore: TransactionStore
    @AppStorage("currencySymbol") private var currencySymbol: String = "$"

    let title: String
    /// Shown under the total, e.g. the period ("Nov 1 – Nov 30").
    let subtitle: String
    let transactions: [Transaction]
    /// Overrides the plain sum, e.g. "Saved" is net of withdrawals.
    var totalOverride: Decimal? = nil
    var emoji: String = ""
    var footnote: String? = nil
    /// For buckets: terms whose trend is fetched from the Insights page.
    var trendTerms: [String]? = nil
    var insights: InsightsViewModel? = nil
    /// Optional link to the full account or group screen.
    var account: Account? = nil
    var group: AccountGroup? = nil
    /// For "Unmatched": suggest words and #tags from these remarks that
    /// could be added to a bucket.
    var suggestsBucketTerms: Bool = false

    @State private var trend: [TrendPoint] = []
    /// Terms added from this screen, with the bucket they went to.
    @State private var addedTerms: [String: String] = [:]

    private var total: Decimal {
        totalOverride ?? transactions.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var sorted: [Transaction] {
        transactions.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    if !emoji.isEmpty {
                        Text(emoji).font(.system(size: 44))
                    }
                    Text(total.formattedCurrency(symbol: currencySymbol))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("\(transactions.count) transaction\(transactions.count == 1 ? "" : "s") · \(subtitle)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            } footer: {
                if let footnote { Text(footnote) }
            }
            .listRowBackground(Color.clear)

            if trendTerms != nil {
                Section(header: Text("Trend")) {
                    RemarkTrendChart(points: trend, currencySymbol: currencySymbol)
                        .frame(height: 120)
                        .padding(.vertical, 4)
                }
            }

            if suggestsBucketTerms, !termCandidates.isEmpty {
                Section {
                    ForEach(termCandidates, id: \.term) { candidate in
                        termCandidateRow(candidate)
                    }
                } header: {
                    Text("Common in these remarks")
                } footer: {
                    Text("Add a word or #tag to a bucket to catch these from now on — and in all your history. The figures update when you go back.")
                }
            }

            Section(header: Text("Transactions")) {
                if sorted.isEmpty {
                    Text("Nothing in this period")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sorted) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let account {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink("Account") { AccountDetailView(account: account) }
                }
            } else if let group {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink("Group") { AccountGroupDetailView(group: group) }
                }
            }
        }
        .task {
            if let trendTerms, let insights {
                trend = await insights.remarkStats(terms: trendTerms).trend
            }
        }
    }

    // MARK: - Bucket Term Suggestions

    struct TermCandidate {
        let term: String
        let count: Int
        let total: Decimal
    }

    /// Words too common to say anything about a payee or purpose.
    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "to", "of", "at", "in", "on", "my", "a", "an", "by", "via"
    ]

    /// The words and #tags that appear in the most of these transactions
    /// (at least 3 letters, no plain numbers), up to six.
    private var termCandidates: [TermCandidate] {
        var stats: [String: (count: Int, total: Decimal)] = [:]
        for tx in transactions {
            let tokens = RemarkMatcher.tokens(of: tx.remark)
            var terms = Set(tokens.tags.map { "#" + $0 })
            let tagBodies = tokens.tags
            for word in tokens.words where word.count >= 3
                && !Self.stopWords.contains(word)
                && !tagBodies.contains(word)
                && !word.allSatisfy({ $0.isNumber || $0 == "." }) {
                terms.insert(word)
            }
            for term in terms {
                let current = stats[term] ?? (0, 0)
                stats[term] = (current.count + 1, current.total + tx.amount)
            }
        }
        return stats
            .map { TermCandidate(term: $0.key, count: $0.value.count, total: $0.value.total) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                if a.total != b.total { return a.total > b.total }
                return a.term < b.term
            }
            .prefix(6)
            .map { $0 }
    }

    @ViewBuilder
    private func termCandidateRow(_ candidate: TermCandidate) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.term)
                    .foregroundColor(candidate.term.hasPrefix("#") ? .accentColor : .primary)
                Text("\(candidate.count) transaction\(candidate.count == 1 ? "" : "s") · \(candidate.total.formattedCurrency(symbol: currencySymbol))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let addedTo = addedTerms[candidate.term] {
                Label("Added to \(addedTo)", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Menu {
                    ForEach(sortedBuckets) { bucket in
                        Button(bucket.name) { add(candidate.term, to: bucket) }
                    }
                    Divider()
                    Button {
                        createBucket(for: candidate.term)
                    } label: {
                        Label("New Bucket “\(bucketName(for: candidate.term))”", systemImage: "plus")
                    }
                } label: {
                    Label("Add to…", systemImage: "plus.circle")
                        .font(.caption.weight(.medium))
                }
                .accessibilityLabel("Add \(candidate.term) to a bucket")
            }
        }
    }

    private var sortedBuckets: [RemarkBucket] {
        transactionStore.remarkBuckets.sorted(by: {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        })
    }

    private func bucketName(for term: String) -> String {
        (term.hasPrefix("#") ? String(term.dropFirst()) : term).capitalized
    }

    private func add(_ term: String, to bucket: RemarkBucket) {
        var updated = bucket
        if !updated.terms.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) {
            updated.terms.append(term)
            transactionStore.saveBucket(updated)
        }
        addedTerms[term] = bucket.name
    }

    private func createBucket(for term: String) {
        let bucket = RemarkBucket(name: bucketName(for: term), terms: [term])
        transactionStore.saveBucket(bucket)
        addedTerms[term] = bucket.name
    }
}
