//
//  RemarkMatcherTests.swift
//  Pocket LedgerTests
//
//  Bucket / lookup term syntax, hashtag parsing, and hashtag autocomplete.
//

import XCTest
@testable import Pocket_Ledger

final class RemarkMatcherTests: XCTestCase {

    private func matches(_ remark: String, _ term: String,
                         file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let parsed = RemarkMatcher.parse(term) else {
            XCTFail("\"\(term)\" didn't parse", file: file, line: line)
            return false
        }
        return RemarkMatcher.matches(RemarkMatcher.tokens(of: remark), parsed)
    }

    func testWordPrefixIsTheDefault() {
        XCTAssertTrue(matches("Starbucks", "star"))
        XCTAssertTrue(matches("Starbucks", "star*"))     // trailing * is the default anyway
        XCTAssertFalse(matches("Mustard", "star"))
        XCTAssertTrue(matches("Teahouse", "tea"))
        XCTAssertFalse(matches("Steak", "tea"))          // matched under the old substring rule
        XCTAssertTrue(matches("Grab/Starbucks", "starbucks"))
    }

    func testQuotedTermIsAnExactWord() {
        XCTAssertFalse(matches("Barber", "\"bar\""))
        XCTAssertTrue(matches("Bar & grill", "\"bar\""))
        XCTAssertTrue(matches("Barber", "bar"))
    }

    func testMultiWordTermsMatchInOrder() {
        XCTAssertTrue(matches("Joe's Coffeehouse", "joe's coffee"))
        XCTAssertFalse(matches("Coffee at Joe's", "joe's coffee"))
        XCTAssertTrue(matches("Co-op groceries", "co-op"))
    }

    func testCurlyApostrophesMatchStraightOnes() {
        XCTAssertTrue(matches("Joe\u{2019}s Coffee", "joe's"))
        XCTAssertTrue(matches("Joe's Coffee", "joe\u{2019}s"))
    }

    func testTagsMatchExactly() {
        XCTAssertTrue(matches("Lunch #work", "#work"))
        XCTAssertTrue(matches("Lunch #Work!", "#work"))
        XCTAssertFalse(matches("Gym #workout", "#work"))
        XCTAssertFalse(matches("C# book", "#book"))
        XCTAssertTrue(matches("Dinner #coffee", "coffee"))  // a plain term also sees tag words
    }

    func testStarMatchesAnywhere() {
        XCTAssertTrue(matches("Coffeebean", "*bean"))
        XCTAssertFalse(matches("Coffeebean", "bean"))
    }

    func testInvalidTermsDoNotParse() {
        for term in ["", "   ", "#", "*", "**", "\"\""] {
            XCTAssertNil(RemarkMatcher.parse(term), "\"\(term)\"")
        }
    }

    func testSegmentsSeparateTagsFromText() {
        let segments = RemarkMatcher.segments(of: "C# book #learn-swift")
        XCTAssertEqual(segments.map { $0.text }, ["C# book ", "#learn-swift"])
        XCTAssertEqual(segments.map { $0.isTag }, [false, true])
        XCTAssertEqual(RemarkMatcher.hashtags(in: "Dinner #DateNight and #work"), ["DateNight", "work"])
    }

    // MARK: - Hashtag autocomplete (RemarkIndex)

    func testHashtagFragmentSuggestsOnlyTags() {
        let food = UUID(), dbs = UUID()
        let transactions = [
            Transaction(type: .outflow, accountID: dbs, categoryID: food, amount: 12, remark: "Lunch #work"),
            Transaction(type: .outflow, accountID: dbs, categoryID: food, amount: 15, remark: "Dinner #work"),
            Transaction(type: .outflow, accountID: dbs, categoryID: food, amount: 60, remark: "Lolla #datenight"),
            Transaction(type: .outflow, accountID: dbs, categoryID: food, amount: 5, remark: "Workshop snacks"),
        ]
        let index = RemarkIndex(transactions: transactions, systemCategoryIDs: [])

        let suggestions = index.suggestions(for: "Coffee #wo", type: .outflow, categoryID: nil)
        XCTAssertEqual(suggestions.map(\.text), ["#work"])
        XCTAssertTrue(suggestions.first?.canAutoAccept ?? false)

        // Tags aren't offered as plain words: "wor" offers Workshop, never "work".
        let plain = index.suggestions(for: "wor", type: .outflow, categoryID: nil).map(\.text)
        XCTAssertTrue(plain.contains("Workshop"))
        XCTAssertFalse(plain.contains { $0.lowercased() == "work" || $0.hasPrefix("#") })
    }

    // MARK: - Bucket editor preview (RemarkCorpus)

    func testCorpusCountsTransactionsNotRemarks() {
        let food = UUID(), plug = UUID(), dbs = UUID()
        let transactions = [
            Transaction(type: .outflow, accountID: dbs, categoryID: food, amount: 5, remark: "Starbucks"),
            Transaction(type: .outflow, accountID: dbs, categoryID: food, amount: 6, remark: "starbucks"),
            Transaction(type: .outflow, accountID: dbs, categoryID: food, amount: 7, remark: "Starbucks Reserve"),
            Transaction(type: .outflow, accountID: dbs, categoryID: plug, amount: 1, remark: "Starbucks"),
        ]
        let corpus = RemarkCorpus(transactions: transactions, plugCategoryIDs: [plug])
        XCTAssertEqual(corpus.count(matching: RemarkMatcher.parse("star")!), 3)   // plug excluded
        XCTAssertEqual(corpus.entries(matchingAnyOf: RemarkMatcher.parse(["star"])).count, 2) // distinct remarks
    }
}
