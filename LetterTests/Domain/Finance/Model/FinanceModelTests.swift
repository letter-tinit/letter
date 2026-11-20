import Foundation
import XCTest
@testable import Domain

final class FinanceModelTests: XCTestCase {
    func test_netWorthSnapshot_calculatesTotalsAndMissingValues() {
        let cash = NetWorthPlanItem(category: .cashAndBank, name: "Cash", displayOrder: 1)
        let investment = NetWorthPlanItem(category: .investment, name: "ETF", displayOrder: 1)
        let debt = NetWorthPlanItem(category: .longTermDebt, name: "Loan", displayOrder: 1)
        let snapshot = NetWorthSnapshot(asOfDate: Date(timeIntervalSince1970: 0))

        snapshot.setAmount(100, for: cash)
        snapshot.setAmount(250, for: investment)
        snapshot.setAmount(80, for: debt)

        XCTAssertEqual(snapshot.total(for: .assets, using: [cash, investment, debt]), 350)
        XCTAssertEqual(snapshot.total(for: .liabilities, using: [cash, investment, debt]), 80)
        XCTAssertEqual(snapshot.netWorth(using: [cash, investment, debt]), 270)
        XCTAssertEqual(snapshot.missingValueCount(using: [cash, investment, debt]), 0)
    }

    func test_financePIN_validationAndMatching() {
        XCTAssertTrue(FinancePIN.isValid("1234"))
        XCTAssertTrue(FinancePIN.isValid("123456"))
        XCTAssertFalse(FinancePIN.isValid("123"))
        XCTAssertFalse(FinancePIN.isValid("1234567"))
        XCTAssertFalse(FinancePIN.isValid("12A4"))
        XCTAssertTrue(FinancePIN.securelyMatches("1234", "1234"))
        XCTAssertFalse(FinancePIN.securelyMatches("1234", "9999"))
    }
}
