//
//  InsightsEngineTests.swift
//  Pocket LedgerTests
//
//  The Four Pillars arithmetic: how income, spending, saving and debt
//  payments are counted, and what's left out.
//

import XCTest
@testable import Pocket_Ledger

final class InsightsEngineTests: XCTestCase {

    // Accounts
    private let dbs = UUID(), card = UUID(), fund = UUID(), fund2 = UUID(), loan = UUID()
    // Categories
    private let salary = UUID(), food = UUID(), travel = UUID(), transfer = UUID(), plug = UUID()

    private let start = Date(timeIntervalSince1970: 1_767_225_600) // 1 Jan 2026
    private func day(_ n: Int) -> Date { start.addingTimeInterval(Double(n) * 86_400 + 3_600) }
    private var month: DateInterval { DateInterval(start: start, duration: 31 * 86_400) }

    private func pair(from source: UUID, to destination: UUID, _ amount: Decimal, day n: Int) -> [Transaction] {
        let a = UUID(), b = UUID()
        return [
            Transaction(id: a, linkedTransactionID: b, type: .outflow, accountID: source,
                        categoryID: transfer, amount: amount, date: day(n)),
            Transaction(id: b, linkedTransactionID: a, type: .inflow, accountID: destination,
                        categoryID: transfer, amount: amount, date: day(n)),
        ]
    }

    private func sampleTransactions() -> [Transaction] {
        [
            Transaction(type: .inflow,  accountID: dbs,  categoryID: salary, amount: 5000, date: day(1)),
            Transaction(type: .outflow, accountID: dbs,  categoryID: food,   amount: 700,  date: day(2)),
            Transaction(type: .outflow, accountID: card, categoryID: food,   amount: 500,  date: day(3)),
            Transaction(type: .outflow, accountID: card, categoryID: travel, amount: 300,  date: day(4), isOutlier: true),
            Transaction(type: .outflow, accountID: dbs,  categoryID: plug,   amount: 1.5,  date: day(11)),
        ]
        + pair(from: dbs, to: fund, 1000, day: 5)     // saved
        + pair(from: fund, to: dbs, 200, day: 6)      // taken out of savings
        + pair(from: dbs, to: loan, 400, day: 7)      // debt paid
        + pair(from: dbs, to: card, 500, day: 8)      // card repayment: counted nowhere
        + pair(from: fund, to: fund2, 50, day: 9)     // goal → goal: not saving
        + pair(from: fund, to: loan, 100, day: 10)    // savings used to pay debt
    }

    private func input(_ transactions: [Transaction], filters: InsightFilters = InsightFilters(),
                       mode: BreakdownMode = .category) -> InsightsInput {
        InsightsInput(
            transactions: transactions,
            filters: filters,
            breakdownMode: mode,
            showsSpending: true,
            accountTypes: [dbs: .debit, card: .limit, fund: .goal, fund2: .goal, loan: .debt],
            accountNames: [dbs: "DBS", card: "Card", fund: "Fund", fund2: "Fund 2", loan: "Loan"],
            activeAccountIDs: [dbs, card, fund, fund2, loan],
            lastReconciled: [dbs: day(30), card: day(30), fund: day(30), fund2: day(30), loan: day(30)],
            categories: [salary: .init(name: "Salary", emoji: "💰"), food: .init(name: "Food", emoji: "🍱"),
                         travel: .init(name: "Travel", emoji: "✈️"), transfer: .init(name: "Transfer", emoji: "⇆"),
                         plug: .init(name: "Reconciliation Adjustment", emoji: "⚖️")],
            plugCategoryIDs: [plug],
            topLevelGroupOfAccount: [:],
            groupNames: [:],
            buckets: [],
            current: month,
            comparison: nil,
            comparisonIsLikeForLike: false,
            trendPeriods: [InsightPeriod(interval: month, label: "Jan", isInProgress: false)],
            now: day(31)
        )
    }

    func testFourPillars() {
        let flows = InsightsEngine.compute(input(sampleTransactions())).flows
        XCTAssertEqual(flows.income, 5000)
        XCTAssertEqual(flows.spentTypical, 1200)          // plug excluded
        XCTAssertEqual(flows.spentOneOff, 300)
        XCTAssertEqual(flows.savedIn, 1000)               // goal → goal ignored
        XCTAssertEqual(flows.savedOut, 300)               // 200 to DBS + 100 to the loan
        XCTAssertEqual(flows.debtPaid, 500)               // 400 + 100, card repayment not counted
        XCTAssertEqual(flows.leftOver, 2300)              // 5000 − 1500 − 700 − 500
    }

    func testExcludingAGoalDropsItsTransfers() {
        var filters = InsightFilters()
        filters.excludedAccountIDs = [fund]
        let flows = InsightsEngine.compute(input(sampleTransactions(), filters: filters)).flows
        XCTAssertEqual(flows.savedIn, 0)
        XCTAssertEqual(flows.savedOut, 0)
        XCTAssertEqual(flows.debtPaid, 400)
    }

    func testExcludeOutliers() {
        var filters = InsightFilters()
        filters.excludeOutliers = true
        let flows = InsightsEngine.compute(input(sampleTransactions(), filters: filters)).flows
        XCTAssertEqual(flows.spentOneOff, 0)
        XCTAssertEqual(flows.spent, 1200)
    }

    func testBreakdownRowsSumToSpentAndContainTheirTransactions() {
        let result = InsightsEngine.compute(input(sampleTransactions()))
        XCTAssertEqual(result.breakdown.map(\.name), ["Food", "Travel"])   // no Transfer, no plug
        XCTAssertEqual(result.breakdown.reduce(Decimal(0)) { $0 + $1.amount }, result.flows.spent)
        for item in result.breakdown {
            XCTAssertEqual(item.transactions.reduce(Decimal(0)) { $0 + $1.amount }, item.amount)
        }
    }

    func testPlugsAndOverdueAccountsReportedAsTrust() {
        var snapshot = input(sampleTransactions())
        snapshot.lastReconciled[card] = nil     // never verified
        let trust = InsightsEngine.compute(snapshot).trust
        XCTAssertEqual(trust.plugTotal, 1.5)
        XCTAssertEqual(trust.overdueAccountNames, ["Card"])
    }

    func testBucketMatchingIgnoresCaseAndBlankTerms() {
        let terms = RemarkMatcher.parse([" Starbucks ", ""])
        XCTAssertEqual(terms.count, 1)
        XCTAssertTrue(RemarkMatcher.matches("STARBUCKS reserve", anyOf: terms))
        XCTAssertFalse(RemarkMatcher.matches("", anyOf: terms))
    }
}
