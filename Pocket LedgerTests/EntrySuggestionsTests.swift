//
//  EntrySuggestionsTests.swift
//  Pocket LedgerTests
//
//  Behaviour of remark autocomplete and "Last time" recall (RemarkIndex).
//

import XCTest
@testable import Pocket_Ledger

final class EntrySuggestionsTests: XCTestCase {

    private let food = UUID(), fun = UUID(), income = UUID(), plug = UUID()
    private let dbs = UUID(), amex = UUID(), wallet = UUID()
    private var index: RemarkIndex!

    private func day(_ n: Int) -> Date {
        Date(timeIntervalSince1970: 1_767_225_600 + Double(n) * 86_400) // 1 Jan 2026 + n days
    }

    override func setUp() {
        super.setUp()
        let legA = UUID(), legB = UUID()
        let transactions: [Transaction] = [
            Transaction(type: .outflow, accountID: dbs,  categoryID: food,   amount: 5,    date: day(1), remark: "Starbucks"),
            Transaction(type: .outflow, accountID: amex, categoryID: food,   amount: 6.2,  date: day(5), remark: "Starbucks"),
            Transaction(type: .outflow, accountID: dbs,  categoryID: food,   amount: 4,    date: day(2), remark: "Coffeebean"),
            Transaction(type: .outflow, accountID: amex, categoryID: fun,    amount: 120,  date: day(3), remark: "Anniversary dinner"),
            Transaction(type: .outflow, accountID: dbs,  categoryID: food,   amount: 7,    date: day(4), remark: "Coffee with Sam"),
            Transaction(type: .inflow,  accountID: dbs,  categoryID: income, amount: 5000, date: day(6), remark: "Salary"),
            Transaction(type: .outflow, accountID: dbs,  categoryID: plug,   amount: 1.5,  date: day(7), remark: "Reconciliation adjustment"),
            Transaction(id: legA, linkedTransactionID: legB, type: .outflow, accountID: dbs,
                        categoryID: UUID(), amount: 50, date: day(8), remark: "Top up"),
            Transaction(id: legB, linkedTransactionID: legA, type: .inflow, accountID: wallet,
                        categoryID: UUID(), amount: 50, date: day(8), remark: "Top up"),
        ]
        index = RemarkIndex(transactions: transactions, systemCategoryIDs: [plug])
    }

    /// What Return/Tab would accept for this input.
    private func accepted(_ remark: String, type: TransactionType = .outflow) -> String? {
        guard !RemarkIndex.currentFragment(of: remark).isEmpty else { return nil }
        return index.suggestions(for: remark, type: type, categoryID: nil)
            .first(where: \.canAutoAccept)?.text
    }

    private func texts(_ remark: String, type: TransactionType = .outflow, category: UUID? = nil) -> [String] {
        index.suggestions(for: remark, type: type, categoryID: category).map(\.text)
    }

    func testContainsMatchIsShownButNotAutoAccepted() {
        XCTAssertEqual(texts("bean"), ["Coffeebean"])
        XCTAssertNil(accepted("bean"))
    }

    func testFinishedKnownWordIsNotExtendedByReturn() {
        XCTAssertNil(accepted("coffee"))
    }

    func testPrefixCompletes() {
        XCTAssertEqual(accepted("Star"), "Starbucks")
        XCTAssertEqual(accepted("Anniversary d"), "Anniversary dinner")
    }

    func testPlugsAreNeverSuggested() {
        XCTAssertFalse(texts("Rec").contains { $0.lowercased().contains("reconciliation") })
        XCTAssertNil(index.lastTransaction(withRemark: "Reconciliation adjustment", type: .outflow))
    }

    func testEmptyRemarkFavoursChosenCategoryAndType() {
        XCTAssertEqual(texts("", category: food), ["Starbucks", "Coffee with Sam", "Coffeebean"])
        XCTAssertEqual(texts("", type: .inflow), ["Salary"])
    }

    func testNoSuggestionsAfterTrailingSpace() {
        XCTAssertEqual(texts("Starbucks "), [])
    }

    func testPhraseIsNotRepeatedAsWord() {
        XCTAssertEqual(texts("Starb"), ["Starbucks"])
    }

    func testLastTimeIsMostRecentOfSameType() {
        let last = index.lastTransaction(withRemark: "  starbucks ", type: .outflow)
        XCTAssertEqual(last?.accountID, amex)
        XCTAssertEqual(last?.amount, 6.2)
        XCTAssertNil(index.lastTransaction(withRemark: "Starbucks", type: .inflow))
    }

    func testTransferRemarkCountsOnceAndHasNoLastTime() {
        XCTAssertEqual(texts("", type: .transfer), ["Top up"])
        XCTAssertNil(index.lastTransaction(withRemark: "Top up", type: .outflow))
    }
}
