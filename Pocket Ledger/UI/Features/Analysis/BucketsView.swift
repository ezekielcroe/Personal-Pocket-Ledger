//
//  BucketsView.swift
//  Pocket Ledger
//
//  Remark buckets: named umbrellas over free-text remarks.
//  Contains the management list, the editor, and the shared trend chart
//  used on the Insights page and in drill-downs.
//

import SwiftUI
import Charts

// MARK: - Trend Chart

/// A small bar chart of per-period amounts. Tap a bar to see its exact
/// amount in a callout; tap elsewhere to dismiss it. The period still in
/// progress is drawn lighter ("so far"), and an optional dashed line marks
/// the typical amount of earlier periods.
struct RemarkTrendChart: View {
    let points: [TrendPoint]
    let currencySymbol: String
    var typical: Decimal? = nil
    @State private var selectedLabel: String?

    var body: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Period", point.label),
                    y: .value("Amount", NSDecimalNumber(decimal: point.amount).doubleValue)
                )
                .foregroundStyle(barColor(for: point))
                .cornerRadius(3)
                .accessibilityLabel(point.label)
                .accessibilityValue(point.amount.formattedCurrency(symbol: currencySymbol)
                                    + (point.isInProgress ? ", so far" : ""))

                if let selectedLabel, selectedLabel == point.label {
                    RuleMark(x: .value("Period", selectedLabel))
                        .foregroundStyle(.clear)
                        .annotation(
                            position: .top,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            VStack(spacing: 2) {
                                Text(point.isInProgress ? "\(point.label) (so far)" : point.label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(point.amount.formattedCurrency(symbol: currencySymbol))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.secondarySystemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            )
                        }
                }
            }

            if let typical, typical > 0 {
                RuleMark(y: .value("Typical", NSDecimalNumber(decimal: typical).doubleValue))
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Typical")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Typical")
                    .accessibilityValue(typical.formattedCurrency(symbol: currencySymbol))
            }
        }
        .chartXSelection(value: $selectedLabel)
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

    private func barColor(for point: TrendPoint) -> Color {
        let base = Color.teal
        if let selectedLabel, selectedLabel != point.label { return base.opacity(0.35) }
        return point.isInProgress ? base.opacity(0.55) : base
    }
}

// MARK: - Term Syntax Help

/// Shared explanation of bucket term syntax (see RemarkMatcher).
private let bucketTermSyntaxHelp = """
star — words starting with "star" (Starbucks, not Mustard)
"bar" — only the word bar (not Barber)
joe's coffee — those words, in order
#work — exactly the tag #work
*bean — anywhere, even mid-word (Coffeebean)
"""

// MARK: - Manage Buckets

struct ManageBucketsView: View {
    @EnvironmentObject var transactionStore: TransactionStore
    @State private var showingAddSheet = false
    /// Distinct remarks, tokenized once, for per-bucket match counts.
    @State private var corpus: RemarkCorpus?

    var body: some View {
        List {
            if transactionStore.remarkBuckets.isEmpty {
                Section(footer: Text("A bucket groups remarks under one name. \"Coffee\" with the terms starbucks, *bean and #coffee counts every transaction whose remark matches any of them.")) {
                    Text("No buckets yet")
                        .foregroundColor(.secondary)
                }
            } else {
                Section(footer: Text("A transaction counts toward a bucket if its remark matches any of the bucket's terms. One transaction can fall into several buckets. Counts cover all time.")) {
                    ForEach(sortedBuckets) { bucket in
                        NavigationLink(destination: EditBucketView(bucket: bucket)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bucket.name)
                                        .font(.body)
                                    Text(bucket.terms.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if let count = matchCount(for: bucket) {
                                    Text("\(count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(count == 0 ? .orange : .secondary)
                                        .accessibilityLabel("\(count) transactions")
                                }
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
                .accessibilityLabel("New bucket")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                EditBucketView(bucket: nil)
            }
        }
        .onAppear { corpus = transactionStore.remarkCorpus() }
        .onChange(of: transactionStore.transactions) { _, _ in corpus = transactionStore.remarkCorpus() }
    }

    private var sortedBuckets: [RemarkBucket] {
        transactionStore.remarkBuckets
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func matchCount(for bucket: RemarkBucket) -> Int? {
        guard let corpus else { return nil }
        return corpus.entries(matchingAnyOf: RemarkMatcher.parse(bucket.terms)).reduce(0) { $0 + $1.count }
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
    @State private var corpus: RemarkCorpus?
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

            Section(header: Text("Terms"), footer: Text(bucketTermSyntaxHelp)) {
                ForEach(terms, id: \.self) { term in
                    HStack {
                        Text(term)
                        Spacer()
                        termCountLabel(for: term)
                    }
                    .accessibilityElement(children: .combine)
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
                        termCountLabel(for: newTerm)
                        Button {
                            addTerm(newTerm)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(RemarkMatcher.parse(newTerm) == nil)
                        .accessibilityLabel("Add term")
                    }
                }

                // Suggestions from words and #tags you've already used
                if isTermFieldFocused {
                    ForEach(termSuggestions, id: \.self) { suggestion in
                        Button {
                            addTerm(suggestion)
                        } label: {
                            HStack {
                                Image(systemName: suggestion.hasPrefix("#") ? "number" : "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(suggestion)
                                    .foregroundColor(.primary)
                                Spacer()
                                termCountLabel(for: suggestion)
                            }
                        }
                    }
                }
            }

            previewSection
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
        .onAppear {
            if corpus == nil { corpus = transactionStore.remarkCorpus() }
        }
    }

    // MARK: - Preview

    /// Terms being previewed: the saved list plus the one being typed, so
    /// you can see what a term would catch before adding it.
    private var previewTerms: [RemarkTerm] {
        RemarkMatcher.parse(terms + [newTerm])
    }

    @ViewBuilder
    private var previewSection: some View {
        if let corpus, !previewTerms.isEmpty {
            let matches = corpus.entries(matchingAnyOf: previewTerms)
            let total = matches.reduce(0) { $0 + $1.count }
            Section {
                if matches.isEmpty {
                    Text("Nothing matches yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(matches.prefix(8), id: \.remark) { entry in
                        HStack {
                            RemarkText.styled(entry.remark)
                                .lineLimit(1)
                            Spacer()
                            Text("×\(entry.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if matches.count > 8 {
                        Text("and \(matches.count - 8) more remark\(matches.count - 8 == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Preview — \(total) transaction\(total == 1 ? "" : "s"), all time")
            } footer: {
                Text("Check this list for remarks that don't belong. A term that's too loose can be tightened with quotes (\"bar\") or replaced by a #tag.")
            }
        }
    }

    /// "42", "no matches" (orange) or "invalid" for a term.
    @ViewBuilder
    private func termCountLabel(for raw: String) -> some View {
        if let term = RemarkMatcher.parse(raw) {
            if let corpus {
                let count = corpus.count(matching: term)
                Text(count == 0 ? "no matches" : "\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(count == 0 ? .orange : .secondary)
                    .accessibilityLabel(count == 0 ? "no matches" : "\(count) transactions")
            }
        } else {
            Text("not a valid term")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }

    // MARK: - Logic

    private var termSuggestions: [String] {
        let typed = newTerm.trimmingCharacters(in: .whitespaces)
        let candidates = typed.hasPrefix("#")
            ? transactionStore.remarkTagSuggestions(completing: typed)
            : transactionStore.remarkWordSuggestions(completing: typed)
        return candidates
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
        guard !term.isEmpty, RemarkMatcher.parse(term) != nil else { return }
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

// Bucket details now open in InsightDrillDownView, which shows the same
// transactions as the bucket's row on the Insights page.
