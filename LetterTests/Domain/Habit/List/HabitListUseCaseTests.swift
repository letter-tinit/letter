import XCTest
@testable import Domain

final class HabitListUseCaseTests: XCTestCase {
    private let useCase = ImpHabitListUseCase()
    private let calendar = HabitTestSupport.calendar

    func test_habits_returnsScheduledItemsAndMovesClosedItemsAfterOpenItems() {
        let date = HabitTestSupport.date(2024, 1, 2)
        let completed = HabitTestSupport.makeHabit(
            id: UUID(),
            name: "Completed",
            sortOrder: 0,
            entries: [entry(date, completedCount: 2)]
        )
        let open = HabitTestSupport.makeHabit(
            id: UUID(),
            name: "Open",
            sortOrder: 1
        )

        let items = useCase.habits(
            from: [completed, open],
            scheduledOn: date,
            relativeTo: date,
            calendar: calendar
        )

        XCTAssertEqual(items.map(\.id), [open.id, completed.id])
        XCTAssertFalse(items[0].entryIsCompleted)
        XCTAssertTrue(items[1].entryIsCompleted)
    }

    func test_dayProgress_averagesActiveScheduledHabitProgressAndIgnoresSkippedHabits() {
        let date = HabitTestSupport.date(2024, 1, 2)
        let complete = HabitTestSupport.makeHabit(
            id: UUID(),
            goalCount: 2,
            entries: [entry(date, completedCount: 2)]
        )
        let skipped = HabitTestSupport.makeHabit(
            id: UUID(),
            goalCount: 2,
            entries: [entry(date, completedCount: 0, status: .skipped)]
        )

        let progress = useCase.dayProgress(
            for: [date],
            habits: [complete, skipped],
            calendar: calendar
        )

        XCTAssertEqual(progress.first?.completionRatio, 1)
        XCTAssertEqual(progress.first?.isComplete, true)
    }

    func test_habits_keepsCompletedHabitsVisibleThroughCompletionDateOnly() {
        let completedAt = HabitTestSupport.date(2024, 1, 2)
        let afterCompletion = HabitTestSupport.date(2024, 1, 3)
        let completed = HabitTestSupport.makeHabit(
            id: UUID(),
            completedAt: completedAt
        )
        let active = HabitTestSupport.makeHabit(id: UUID())

        let completionDayItems = useCase.habits(
            from: [completed, active],
            scheduledOn: completedAt,
            relativeTo: completedAt,
            calendar: calendar
        )
        let laterItems = useCase.habits(
            from: [completed, active],
            scheduledOn: afterCompletion,
            relativeTo: afterCompletion,
            calendar: calendar
        )

        XCTAssertEqual(completionDayItems.map(\.id), [completed.id, active.id])
        XCTAssertEqual(laterItems.map(\.id), [active.id])
    }

    private func entry(
        _ date: Date,
        completedCount: Int,
        status: HabitEntryStatus = .active
    ) -> HabitEntrySnapshot {
        HabitEntrySnapshot(
            date: date,
            completedCount: completedCount,
            status: status
        )
    }
}
