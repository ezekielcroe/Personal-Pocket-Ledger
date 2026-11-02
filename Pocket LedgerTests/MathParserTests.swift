//
//  MathParserTests.swift
//  Pocket LedgerTests
//
//  Add to a Unit Testing Bundle target (File ▸ New ▸ Target ▸ Unit Testing
//  Bundle) whose host application is Pocket Ledger, then run with ⌘U.
//

import XCTest
@testable import Pocket_Ledger

final class MathParserTests: XCTestCase {

    private let dotLocale = Locale(identifier: "en_US")
    private let commaLocale = Locale(identifier: "de_DE")

    private func assertCalc(_ input: String, _ expected: String,
                            locale: Locale? = nil,
                            file: StaticString = #filePath, line: UInt = #line) {
        let result = MathParser.calculate(input, locale: locale ?? dotLocale)
        XCTAssertEqual(result, Decimal(string: expected, locale: Locale(identifier: "en_US_POSIX")),
                       "\"\(input)\"", file: file, line: line)
    }

    // MARK: - Arithmetic

    func testDivisionIsNotIntegerDivision() {
        assertCalc("45/2", "22.5")        // NSExpression gave 22
        assertCalc("45 / 2", "22.5")
        assertCalc("7/2", "3.5")
    }

    func testDecimalAccuracy() {
        assertCalc("0.1+0.2", "0.3")      // no Double round-off
        assertCalc("19.99*3", "59.97")
    }

    func testRoundsToCents() {
        assertCalc("100/3", "33.33")
        assertCalc("2/3", "0.67")
        assertCalc("2.005", "2.01")
    }

    func testPrecedenceAndParentheses() {
        assertCalc("12.50+3*2", "18.5")
        assertCalc("(30+15)/3", "15")
        assertCalc("10-2-3", "5")          // left-associative
        assertCalc("100/10/2", "5")
    }

    func testNegatives() {
        assertCalc("-50", "-50")           // Reconcile accepts negative balances
        assertCalc("10-20", "-10")
        assertCalc("5*-2", "-10")
        assertCalc("5/-2", "-2.5")
        assertCalc("--5", "5")
    }

    // MARK: - Live typing

    func testIncompleteInputUsesWhatIsThere() {
        assertCalc("50+", "50")
        assertCalc("12.", "12")
        assertCalc("5+.", "5")
        assertCalc("(10+5", "15")
        assertCalc(".5", "0.5")
        assertCalc("10+.5", "10.5")
    }

    // MARK: - Invalid input (previously could crash)

    func testMalformedInputReturnsZeroWithoutCrashing() {
        for input in ["1.2.3", "5*/2", "5/*2", "5)", "()", ".", "+", "", "abc"] {
            assertCalc(input, "0")
            XCTAssertNil(MathParser.evaluate(input, locale: dotLocale), "\"\(input)\"")
        }
    }

    func testDivisionByZero() {
        assertCalc("5/0", "0")
        XCTAssertNil(MathParser.evaluate("5/0", locale: dotLocale))
    }

    func testPathologicalNestingDoesNotOverflow() {
        _ = MathParser.calculate(String(repeating: "(", count: 10_000) + "1")
        _ = MathParser.calculate(String(repeating: "-", count: 10_000) + "1")
    }

    // MARK: - Symbols and locales

    func testSymbolsAndStrayCharacters() {
        assertCalc("$45.00", "45")
        assertCalc("45÷2", "22.5")
        assertCalc("3×4", "12")
        assertCalc("1,000", "1000")        // grouping comma in dot locales
    }

    func testCommaDecimalLocale() {
        assertCalc("4,50", "4.5", locale: commaLocale)       // was 450
        assertCalc("1,5+1,5", "3", locale: commaLocale)
        assertCalc("45/2", "22.5", locale: commaLocale)
        assertCalc("4.50", "4.5", locale: commaLocale)       // "." still works
    }
}
