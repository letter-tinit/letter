import XCTest
@testable import Domain

final class HabitEntryUseCaseTests: XCTestCase {
    private let useCase = ImpHabitEntryUseCase()
    private let calendar = HabitTestSupport.calendar
    private let now = HabitTestSupport.date(2024, 1, 5)

    func test_updateProgress_upsertsActiveEntryForPastDate() {
        let habit = HabitTestSupport.makeHabit()

        let mutation = useCase.updateProgress(
            for: habit,
            on: HabitTestSupport.date(2024, 1, 2),
            completedCount: 1,
            note: nil,
            calendar: calendar,
            now: now
        )

        guard case .upsert(let values) = mutation else {
            return XCTFail("Expected upsert")
        }
        XCTAssertEqual(values.completedCount, 1)
        XCTAssertEqual(values.status, .active)
        XCTAssertEqual(values.note, "")
    }

    func test_updateProgress_rejectsFutureDate() {
        let habit = HabitTestSupport.makeHabit()

        let mutation = useCase.updateProgress(
            for: habit,
            on: HabitTestSupport.date(2024, 1, 6),
            completedCount: 1,
            note: nil,
            calendar: calendar,
            now: now
        )

        guard case .rejected = mutation else {
            return XCTFail("Expected rejected")
        }
    }

    func test_updateProgress_returnsUnchangedForEmptyNewEntry() {
        let habit = HabitTestSupport.makeHabit()

        let mutation = useCase.updateProgress(
            for: habit,
            on: HabitTestSupport.date(2024, 1, 2),
            completedCount: 0,
            note: nil,
            calendar: calendar,
            now: now
        )

        guard case .unchanged = mutation else {
            return XCTFail("Expected unchanged")
        }
    }

    func test_skip_rejectsCompletedEntry() {
        let habit = HabitTestSupport.makeHabit(
            entries: [
                HabitEntrySnapshot(
                    date: HabitTestSupport.date(2024, 1, 2),
                    completedCount: 2,
                    status: .active
                )
            ]
        )

        let mutation = useCase.skip(
            habit,
            on: HabitTestSupport.date(2024, 1, 2),
            calendar: calendar,
            now: now
        )

        guard case .rejected = mutation else {
            return XCTFail("Expected rejected")
        }
    }

    func test_skip_upsertsSkippedEntryForScheduledDate() {
        let habit = HabitTestSupport.makeHabit()

        let mutation = useCase.skip(
            habit,
            on: HabitTestSupport.date(2024, 1, 2),
            calendar: calendar,
            now: now
        )

        guard case .upsert(let values) = mutation else {
            return XCTFail("Expected upsert")
        }
        XCTAssertEqual(values.completedCount, 0)
        XCTAssertEqual(values.status, .skipped)
    }

    func test_reset_allowsSkippedFutureEntry() {
        let habit = HabitTestSupport.makeHabit(
            entries: [
                HabitEntrySnapshot(
                    date: HabitTestSupport.date(2024, 1, 6),
                    completedCount: 0,
                    status: .skipped
                )
            ]
        )

        let mutation = useCase.reset(
            habit,
            on: HabitTestSupport.date(2024, 1, 6),
            calendar: calendar,
            now: now
        )

        guard case .upsert(let values) = mutation else {
            return XCTFail("Expected upsert")
        }
        XCTAssertEqual(values.status, .active)
        XCTAssertEqual(values.completedCount, 0)
    }
}
