import Foundation
import Observation

/// Runtime calendar preferences shared by presentation models that need calendar layout.
@Observable
final class CalendarPreferences {
    private(set) var weekStartsOnMonday: Bool

    init(weekStartsOnMonday: Bool = true) {
        self.weekStartsOnMonday = weekStartsOnMonday
    }

    var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartsOnMonday ? 2 : 1
        return calendar
    }

    var orderedWeekdays: [Int] {
        weekStartsOnMonday
            ? [1, 2, 3, 4, 5, 6, 0]
            : [0, 1, 2, 3, 4, 5, 6]
    }

    func update(weekStartsOnMonday: Bool) {
        self.weekStartsOnMonday = weekStartsOnMonday
    }
}
