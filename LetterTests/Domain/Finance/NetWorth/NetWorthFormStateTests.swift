import Foundation
import XCTest
@testable import Domain

final class NetWorthFormStateTests: XCTestCase {
    func test_itemValidatedInput_trimsNameAndParsesCommaSeparatedAmount() throws {
        var formState = NetWorthItemFormState()
        formState.category = .financialAssets
        formState.name = "  ETF  "
        formState.amountText = "1,250.75"

        let input = try formState.validatedInput()

        XCTAssertEqual(input.category, .financialAssets)
        XCTAssertEqual(input.name, "ETF")
        XCTAssertEqual(input.amount, Decimal(string: "1250.75"))
    }

    func test_itemValidatedInput_rejectsBlankName() {
        var formState = NetWorthItemFormState()
        formState.name = "  "
        formState.amountText = "100"

        XCTAssertThrowsError(try formState.validatedInput()) { error in
            XCTAssertEqual(error as? NetWorthItemFormValidationError, .nameRequired)
        }
    }

    func test_itemValidatedInput_rejectsInvalidOrNegativeAmount() {
        var invalidTextState = NetWorthItemFormState()
        invalidTextState.name = "Cash"
        invalidTextState.amountText = "abc"

        XCTAssertThrowsError(try invalidTextState.validatedInput()) { error in
            XCTAssertEqual(error as? NetWorthItemFormValidationError, .invalidAmount)
        }

        var negativeState = NetWorthItemFormState()
        negativeState.name = "Debt"
        negativeState.amountText = "-1"

        XCTAssertThrowsError(try negativeState.validatedInput()) { error in
            XCTAssertEqual(error as? NetWorthItemFormValidationError, .invalidAmount)
        }
    }

    func test_itemFormStateInitializesFromPlanItemAndOptionalAmount() {
        let item = NetWorthPlanItem(
            category: .shortTermDebt,
            name: "Credit card",
            displayOrder: 1
        )

        let populatedState = NetWorthItemFormState(item: item, amount: 42.5)
        let blankAmountState = NetWorthItemFormState(item: item, amount: nil)

        XCTAssertEqual(populatedState.category, .shortTermDebt)
        XCTAssertEqual(populatedState.name, "Credit card")
        XCTAssertEqual(populatedState.amountText, "42.5")
        XCTAssertEqual(blankAmountState.amountText, "")
    }

    func test_snapshotValidatedMonth_returnsStartOfMonthWhenUnique() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formState = CreateNetWorthSnapshotFormState(
            month: calendar.date(from: DateComponents(year: 2026, month: 9, day: 24))!
        )

        let month = try formState.validatedMonth(
            existingSnapshots: [
                NetWorthSnapshot(
                    asOfDate: calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
                )
            ],
            calendar: calendar
        )

        XCTAssertEqual(
            month,
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
        )
    }

    func test_snapshotValidatedMonth_rejectsDuplicateMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formState = CreateNetWorthSnapshotFormState(
            month: calendar.date(from: DateComponents(year: 2026, month: 9, day: 24))!
        )
        let existingSnapshot = NetWorthSnapshot(
            asOfDate: calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        )

        XCTAssertThrowsError(
            try formState.validatedMonth(existingSnapshots: [existingSnapshot], calendar: calendar)
        ) { error in
            XCTAssertEqual(error as? CreateNetWorthSnapshotFormValidationError, .duplicateMonth)
        }
    }
}
