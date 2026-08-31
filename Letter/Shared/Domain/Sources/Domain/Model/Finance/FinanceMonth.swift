import Foundation
import Utility

public enum FinanceSettings {
    public static let earliestMonthKey = "finance.earliestMonth"
}

/// A calendar month shared by finance features without coupling their domain models.
public struct FinanceMonth: Hashable, Identifiable, Comparable {
    public let startDate: Date

    public init(_ date: Date, calendar: Calendar = .current) {
        startDate = calendar.startOfMonth(for: date)
    }

    public var id: Date { startDate }

    public var title: String {
        startDate.toString(withFormat: .monthAndYear)
    }

    public static func < (lhs: FinanceMonth, rhs: FinanceMonth) -> Bool {
        lhs.startDate < rhs.startDate
    }
}

public struct FinanceMonthTimeline {
    public static func months(
        from dates: [Date],
        startingAt earliestMonth: FinanceMonth,
        through endDate: Date = .now
    ) -> [FinanceMonth] {
        let dataStart = dates.map { FinanceMonth($0) }.min()
        let start = min(dataStart ?? earliestMonth, earliestMonth)

        return start.startDate
            .generateMonthsTo(to: endDate)
            .map { FinanceMonth($0) }
    }
}
