import Foundation
import Observation
import Domain
import Core
import Utility
import Styleguide

/// Runtime calendar preferences shared by presentation models that need calendar layout.
@Observable
public final class CalendarPreferences {
    private(set) var weekStartsOnMonday: Bool

    public init(weekStartsOnMonday: Bool = true) {
        self.weekStartsOnMonday = weekStartsOnMonday
    }

    public var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartsOnMonday ? 2 : 1
        return calendar
    }

    public var orderedWeekdays: [Int] {
        weekStartsOnMonday
            ? [1, 2, 3, 4, 5, 6, 0]
            : [0, 1, 2, 3, 4, 5, 6]
    }

    public func update(weekStartsOnMonday: Bool) {
        self.weekStartsOnMonday = weekStartsOnMonday
    }
}
