import Foundation

/// Inclusive history days represented as half-open intervals. Missing entries
/// after the first record remain meaningful until the habit ends or is archived.
public struct HabitStatisticsAvailability: Equatable {
    public let ranges: [UUID: DateInterval]

    public init(habits: [HabitSnapshot], today: Date, calendar: Calendar) {
        ranges = habits.reduce(into: [:]) { result, habit in
            let endDay = [habit.endDate, habit.archivedAt].compactMap { $0 }
                .map { calendar.startOfDay(for: $0) }
                .reduce(calendar.startOfDay(for: today), min)
            let startDay = calendar.startOfDay(for: habit.effectiveStartDate)
            let firstRecord = habit.entries.map { calendar.startOfDay(for: $0.date) }
                .filter { $0 >= startDay && $0 <= endDay }.min()
            guard let firstRecord,
                  let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: endDay) else { return }
            result[habit.id] = DateInterval(start: firstRecord, end: exclusiveEnd)
        }
    }

    public func includes(habitID: UUID, period: DateInterval) -> Bool {
        guard let range = ranges[habitID] else { return false }
        return range.start < period.end && period.start < range.end
    }

    public func periods(
        for habitIDs: [UUID], component: Calendar.Component, calendar: Calendar
    ) -> [Date] {
        let selectedRanges = habitIDs.compactMap { ranges[$0] }
        guard let start = selectedRanges.map(\.start).min(),
              let end = selectedRanges.map(\.end).max(),
              var period = calendar.dateInterval(of: component, for: start) else { return [] }
        var dates: [Date] = []
        while period.start < end {
            if selectedRanges.contains(where: { $0.start < period.end && period.start < $0.end }) {
                dates.append(period.start)
            }
            guard let next = calendar.dateInterval(of: component, for: period.end),
                  next.start > period.start else { break }
            period = next
        }
        return dates
    }
}
