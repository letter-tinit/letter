import Foundation

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
    static func months(from dates: [Date], through endDate: Date = .now) -> [FinanceMonth] {
        guard let firstDate = dates.min() else {
            return [FinanceMonth(endDate)]
        }

        return firstDate
            .generateMonthsTo(to: endDate)
            .map { FinanceMonth($0) }
    }
}
