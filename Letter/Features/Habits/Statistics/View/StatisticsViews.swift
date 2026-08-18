//
//  StatisticsViews.swift
//  Habit
//
//  Created by TiniT on 21/5/26.
//

import SwiftUI

enum StatisticsScope: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

struct StatisticsTableHeader: View {
    @Binding var scope: StatisticsScope
    @Binding var date: Date

    private var periodTitle: String {
        switch scope {
        case .week:
            weekRangeTitle
        case .month:
            date.toString(withFormat: .custom("MMMM yyyy"))
        case .year:
            date.toString(withFormat: .custom("yyyy"))
        }
    }

    private var weekRangeTitle: String {
        let dates = weekDates

        guard let start = dates.first, let end = dates.last else {
            return date.toString(withFormat: .custom("MMM d"))
        }

        if AppCalendar.current.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(start.toString(withFormat: .custom("MMM d")))-\(end.toString(withFormat: .custom("d")))"
        }

        return "\(start.toString(withFormat: .custom("MMM d")))~\(end.toString(withFormat: .custom("MMM d")))"
    }

    private var weekDates: [Date] {
        guard let interval = AppCalendar.current.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        return (0..<7).compactMap {
            AppCalendar.current.date(byAdding: .day, value: $0, to: interval.start)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Statistics", selection: $scope) {
                ForEach(StatisticsScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button {
                    changePeriod(by: -1)
                } label: {
                    Image(module: "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Text(periodTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity)

                Button {
                    changePeriod(by: 1)
                } label: {
                    Image(module: "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: scope, { _, _ in
            Haptic.selection()
            resetPeriod()
        })
        .padding()
        .borderedBackground(cornerRadius: 18)
    }

    private func changePeriod(by value: Int) {
        let component: Calendar.Component

        switch scope {
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        case .year:
            component = .year
        }

        guard let newDate = AppCalendar.current.date(byAdding: component, value: value, to: date) else {
            return
        }

        baseAnimation {
            Haptic.selection()
            date = newDate
        }
    }

    private func resetPeriod() {
        date = Date()
    }
}

struct StatisticsOverviewView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    let habit: Habit
    let scope: StatisticsScope
    let date: Date
    let usesSimplifiedMode: Bool

    private var summary: HabitStatisticSummary {
        habitViewModel.statisticSummary(for: habit, scope: scope, containing: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // MARK: - Statistic Properties
            if !usesSimplifiedMode {
                HabitNameBlock(habit: habit)

                StatisticSummaryTable(summary: summary, habit: habit)
            }

            // MARK: - Statistic check mark
            StatisticCheckMarkView(
                habit: habit,
                scope: scope,
                date: date,
                usesCompactHeader: usesSimplifiedMode
            )
        }
        .padding()
    }
}

struct HabitNameBlock: View {
    let habit: Habit
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(module: habit.icon)
                .font(.title3)
                .frame(width: 42, height: 42)
                .background(Color(hex: habit.colorHex).opacity(0.30))
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(habit.name)
                        .font(.headline)
                        .fontDesign(.rounded)

                    if habit.isArchived {
                        Text("Archived")
                            .font(.caption2.weight(.semibold))
                            .fontDesign(.rounded)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.14))
                            .clipShape(.capsule)
                    }
                }

                Text("\(habit.currentStreak) current streak")
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct StatisticCheckMarkView: View {
    let habit: Habit
    let scope: StatisticsScope
    let date: Date
    let usesCompactHeader: Bool

    var body: some View {
        switch scope {
        case .week:
            WeeklyStatisticsView(
                habit: habit,
                date: date,
                usesCompactHeader: usesCompactHeader
            )
        case .month:
            MonthlyStatisticsView(
                habit: habit,
                date: date,
                usesCompactHeader: usesCompactHeader
            )
        case .year:
            YearlyStatisticsView(
                habit: habit,
                date: date,
                usesCompactHeader: usesCompactHeader
            )
        }
    }
}

struct StatisticPeriodHeader: View {
    let habit: Habit
    let progress: Double
    let title: String
    let subtitle: String
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CircularWithTitleProgressView(
                progress: progress,
                title: "\(Int(progress * 100))%",
                size: isCompact ? 44 : 52,
                tintColor: Color(hex: habit.colorHex),
                fontWeight: .bold,
                image: isCompact ? Image(module: habit.icon) : nil
            )

            VStack(alignment: .leading, spacing: 4) {
                if isCompact {
                    HStack(spacing: 8) {
                        Text(habit.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)

                        if habit.isArchived {
                            Text("Archived")
                                .font(.caption2.weight(.semibold))
                                .fontDesign(.rounded)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.secondary.opacity(0.14))
                                .clipShape(.capsule)
                        }
                    }
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                if !isCompact {
                    Text(subtitle)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct StatisticSummaryTable: View {
    let summary: HabitStatisticSummary
    let habit: Habit

    private var progressText: String {
        "\(Int(summary.progress * 100))%"
    }

    private var completedDaysText: String {
        "\(summary.completedDays)/\(summary.scheduledDays)"
    }

    private var skippedDaysText: String {
        "\(summary.skippedDays)"
    }

    private var totalProgressText: String {
        if habit.goalType == .count {
            "\(summary.totalCompletedCount)/\(summary.totalTargetCount) \(habit.goalUnit)"
        } else {
            "\(summary.totalCompletedCount)/\(summary.totalTargetCount)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            statisticRow(title: "Progress", value: progressText)

            Divider().opacity(0.35)

            statisticRow(title: "Completed days", value: completedDaysText)

            Divider().opacity(0.35)

            statisticRow(title: "Skipped days", value: skippedDaysText)

            Divider().opacity(0.35)

            statisticRow(title: "Total", value: totalProgressText)

            Divider().opacity(0.35)

            HStack {
                statisticColumn(title: "Current streak", value: "\(habit.currentStreak)")

                Divider().opacity(0.35)

                statisticColumn(title: "Best streak", value: "\(habit.longestStreak)")
            }
            .frame(minHeight: 46)
        }
        .fontDesign(.rounded)
        .padding(.vertical, 2)
    }

    private func statisticRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 32)
    }

    private func statisticColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WeeklyStatisticsView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    let habit: Habit
    let date: Date
    let usesCompactHeader: Bool

    private var weekDates: [Date] {
        habitViewModel.weekDates(containing: date)
    }

    private var weekTitle: String {
        guard let start = weekDates.first, let end = weekDates.last else {
            return "Selected week"
        }

        return "\(start.toString(withFormat: .custom("MMM d")))-\(end.toString(withFormat: .custom("MMM d")))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatisticPeriodHeader(
                habit: habit,
                progress: habitViewModel.completionRatioForWeek(for: habit, containing: date),
                title: weekTitle,
                subtitle: "Weekly progress",
                isCompact: usesCompactHeader
            )

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weekDates, id: \.self) { day in
                    weekDayColumn(for: day)
                }
            }
            .frame(minHeight: 118)
        }
    }

    private func weekDayColumn(for day: Date) -> some View {
        let isScheduled = habitViewModel.isScheduled(habit, on: day)
        let isSkipped = habitViewModel.isSkipped(habit, on: day)
        let progress = habitViewModel.completionRatio(for: habit, on: day)
        let displayHeight = 68.0

        return VStack(spacing: 7) {
            Text(day.toString(withFormat: .dayNameSymbol))
                .font(.caption2)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)

            Group {
                if isScheduled {
                    if isSkipped {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.cyan.opacity(0.14))
                            .overlay {
                                Image(module: "airplane")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.cyan)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(habit.gradient)
                            .opacity(progress)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.025))
                        .overlay {
                            Image(module: "circle.fill")
                                .font(.system(size: 10))
                                .fontDesign(.rounded)
                                .fontWeight(.black)
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(height: displayHeight)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 2)
            }

            Text(day.toString(withFormat: .dayNo))
                .font(.caption2)
                .fontWeight(day.isToday() ? .bold : .regular)
                .fontDesign(.rounded)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MonthlyStatisticsView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    let habit: Habit
    let date: Date
    let usesCompactHeader: Bool

    private let itemSpacing: CGFloat = HabitConstant.screenWidth / 40

    private var monthTitle: String {
        date.toString(withFormat: .custom("MMMM yyyy"))
    }

    private var paddedDates: [Date?] {
        guard let firstDate = habitViewModel.monthDates(containing: date).first else {
            return []
        }

        let weekday = AppCalendar.current.component(.weekday, from: firstDate) - 1
        let leadingEmptyDays = habitViewModel.orderedWeekdays.firstIndex(of: weekday) ?? 0

        return Array(repeating: nil, count: leadingEmptyDays) + habitViewModel.monthDates(containing: date).map(Optional.some)
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: itemSpacing), count: 7)
        VStack(alignment: .leading, spacing: 14) {
            StatisticPeriodHeader(
                habit: habit,
                progress: habitViewModel.completionRatioForMonth(for: habit, containing: date),
                title: monthTitle,
                subtitle: "Monthly progress",
                isCompact: usesCompactHeader
            )

            LazyVGrid(columns: columns, spacing: itemSpacing) {
                ForEach(habitViewModel.orderedWeekdays, id: \.self) { weekday in
                    Text(shortWeekdayName(for: weekday))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(paddedDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let progress = habitViewModel.completionRatio(for: habit, on: date)
                        let isScheduled = habitViewModel.isScheduled(habit, on: date)
                        let isSkipped = habitViewModel.isSkipped(habit, on: date)
                        ZStack(alignment: .center) {
                            Group {
                                if isScheduled {
                                    if isSkipped {
                                        Color.cyan.opacity(0.14)
                                            .overlay {
                                                Image(module: "airplane")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(.cyan)
                                            }
                                    } else {
                                        habit.gradient
                                            .opacity(progress)
                                    }
                                } else {
                                    Color.primary.opacity(0.025)
                                        .overlay {
                                            Image(module: "circle.fill")
                                                .font(.system(size: 10))
                                                .fontDesign(.rounded)
                                                .fontWeight(.black)
                                                .foregroundStyle(.tertiary)
                                        }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: itemSpacing))
                            .aspectRatio(1, contentMode: .fit)

                            Text(date.toString(withFormat: .dayNo))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                                .foregroundStyle(.primary.opacity(isSkipped ? 0 : progress))
                                .opacity(isScheduled ? 1 : 0)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: itemSpacing)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 2)
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.bottom, 10)
        }
    }

    private func tintColor(for progress: Double) -> Color {
        switch progress {
        case 0:
                .warmGray.opacity(0.35)
        case 0..<0.34:
                .sunsetOrange
        case 0.34..<0.67:
                .goldenYellow
        default:
                .emeraldGreen
        }
    }

    private func shortWeekdayName(for weekday: Int) -> String {
        switch weekday {
        case 0: "Sun"
        case 1: "Mon"
        case 2: "Tue"
        case 3: "Wed"
        case 4: "Thu"
        case 5: "Fri"
        case 6: "Sat"
        default: ""
        }
    }
}

struct YearlyStatisticsView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    let habit: Habit
    let date: Date
    let usesCompactHeader: Bool

    private let cellSize: CGFloat = 10

    private var yearTitle: String {
        date.toString(withFormat: .custom("yyyy"))
    }

    private var weeks: [[Date]] {
        let calendar = AppCalendar.current
        guard
            let yearInterval = calendar.dateInterval(of: .year, for: date),
            let startWeek = calendar.dateInterval(of: .weekOfYear, for: yearInterval.start),
            let lastDay = calendar.date(byAdding: .day, value: -1, to: yearInterval.end),
            let endWeek = calendar.dateInterval(of: .weekOfYear, for: lastDay)
        else {
            return []
        }

        var weeks: [[Date]] = []
        var currentDate = calendar.startOfDay(for: startWeek.start)

        while currentDate < endWeek.end {
            let week = (0..<7).compactMap {
                calendar.date(byAdding: .day, value: $0, to: currentDate)
            }
            weeks.append(week)

            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) else {
                break
            }

            currentDate = nextWeek
        }

        return weeks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatisticPeriodHeader(
                habit: habit,
                progress: habitViewModel.completionRatioForYear(for: habit, containing: date),
                title: yearTitle,
                subtitle: "Yearly progress",
                isCompact: usesCompactHeader
            )

            AppScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(habitViewModel.orderedWeekdays, id: \.self) { weekday in
                            Text(shortWeekdayName(for: weekday))
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: cellSize)
                        }
                    }

                    HStack(alignment: .top, spacing: 4) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: 4) {
                                ForEach(week, id: \.self) { date in
                                    contributionCell(for: date)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func contributionCell(for date: Date) -> some View {
        let calendar = AppCalendar.current
        let isCurrentYear = calendar.isDate(date, equalTo: self.date, toGranularity: .year)
        let progress = habitViewModel.completionRatio(for: habit, on: date)
        let isScheduled = habitViewModel.isScheduled(habit, on: date)
        let isSkipped = habitViewModel.isSkipped(habit, on: date)

        return Group {
            if isScheduled {
                if isSkipped {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.cyan.opacity(0.45))
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(habit.gradient)
                        .opacity(progress)
                }
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.025))
                    .overlay {
                        Image(module: "circle.fill")
                            .font(.system(size: 2))
                            .fontDesign(.rounded)
                            .fontWeight(.regular)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.primary.opacity(isCurrentYear ? 0.10 : 0), lineWidth: 0.5)
        }
    }

    private func shortWeekdayName(for weekday: Int) -> String {
        switch weekday {
        case 0: "S"
        case 1: "M"
        case 2: "T"
        case 3: "W"
        case 4: "T"
        case 5: "F"
        case 6: "S"
        default: ""
        }
    }
}
