import Foundation
import XCTest
@testable import Domain

final class FinanceModelTests: XCTestCase {
    func test_budgetMethod_generatesExpectedFiftyThirtyTwentyBuckets() {
        let buckets = BudgetMethod.fiftyThirtyTwenty.generateBucketByIncome(1000)

        XCTAssertEqual(buckets.map(\.kind), [.needs, .wants, .savings])
        XCTAssertEqual(buckets.map(\.amount), [500, 300, 200])
    }

    func test_budget_availableAmount_distributesDeficitAcrossPositiveRemainingAllocations() {
        let budget = Budget.make(
            periodStart: Date(timeIntervalSince1970: 0),
            income: 1000,
            method: .fiftyThirtyTwenty,
            buckets: [
                BudgetBucket(kind: .needs, ratio: 0.5, amount: 500),
                BudgetBucket(kind: .wants, ratio: 0.3, amount: 300),
                BudgetBucket(kind: .savings, ratio: 0.2, amount: 200)
            ]
        )
        let needs = budget.allocations[0]
        let wants = budget.allocations[1]
        let savings = budget.allocations[2]
        needs.transactions.append(
            BudgetTransaction(
                budget: budget,
                allocation: needs,
                type: .expense,
                title: "Rent",
                amount: 600,
                paymentMethod: .cash
            )
        )

        XCTAssertEqual(budget.availableAmount(for: wants), 240)
        XCTAssertEqual(budget.availableAmount(for: savings), 160)
    }

    func test_netWorthSnapshot_calculatesTotalsAndMissingValues() {
        let cash = NetWorthPlanItem(category: .cashAndCashEquivalents, name: "Cash", displayOrder: 1)
        let investment = NetWorthPlanItem(category: .financialAssets, name: "ETF", displayOrder: 1)
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
