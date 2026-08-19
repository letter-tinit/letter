import Foundation

enum FinanceSettings {
    static let earliestMonthKey = "finance.earliestMonth"
}

/// A calendar month shared by finance features without coupling their domain models.
struct FinanceMonth: Hashable, Identifiable, Comparable {
    let startDate: Date

    init(_ date: Date, calendar: Calendar = .current) {
        startDate = calendar.startOfMonth(for: date)
    }

    var id: Date { startDate }

    var title: String {
        startDate.toString(withFormat: .monthAndYear)
    }

    static func < (lhs: FinanceMonth, rhs: FinanceMonth) -> Bool {
        lhs.startDate < rhs.startDate
    }
}

struct FinanceMonthTimeline {
    static func months(
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
