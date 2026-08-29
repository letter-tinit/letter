//
//  StatisticsViews.swift
//  Letter
//
//  Created by TiniT on 21/5/26.
//

import SwiftUI

enum StatisticsScope: String, CaseIterable {
    case week = "habit.statistics.week"
    case month = "habit.statistics.month"
    case year = "habit.statistics.year"
}

struct StatisticsTableHeaderView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
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

        if viewModel.calendar.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(start.toString(withFormat: .custom("MMM d")))-\(end.toString(withFormat: .custom("d")))"
        }

        return "\(start.toString(withFormat: .custom("MMM d")))~\(end.toString(withFormat: .custom("MMM d")))"
    }

    private var weekDates: [Date] {
        guard let interval = viewModel.calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }

        return (0..<7).compactMap {
            viewModel.calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppPicker(
                "habit.statistics.title".localized,
                selection: $scope,
                layout: .control
            ) {
                ForEach(StatisticsScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue.localized).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button {
                    changePeriod(by: -1)
                } label: {
                    Image(module: "chevron.left")
                        .customFont(.caption, weight: .bold)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Text(periodTitle)
                    .customFont(.subheadline, weight: .semibold)
                    .frame(maxWidth: .infinity)

                Button {
                    changePeriod(by: 1)
                } label: {
                    Image(module: "chevron.right")
                        .customFont(.caption, weight: .bold)
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
        .appGlassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 18)
        )
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

        guard let newDate = viewModel.calendar.date(byAdding: component, value: value, to: date) else {
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
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    let habit: Habit
    let scope: StatisticsScope
    let date: Date
    let usesSimplifiedMode: Bool

    var body: some View {
        let summary = viewModel.statisticSummary(
            for: habit,
            scope: scope,
            containing: date
        )

        VStack(alignment: .leading, spacing: 14) {
            // MARK: - Statistic Properties
            if !usesSimplifiedMode {
                HabitNameBlockView(habit: habit)

                StatisticSummaryTableView(summary: summary, habit: habit)
            }

            // MARK: - Statistic check mark
            StatisticCheckMarkView(
                habit: habit,
                scope: scope,
                date: date,
                progress: summary.progress,
                usesCompactHeader: usesSimplifiedMode
            )
        }
        .padding()
    }
}

struct HabitNameBlockView: View {
    let habit: Habit
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(module: habit.icon)
                .customFont(.title3)
                .frame(width: 42, height: 42)
                .background(Color(hex: habit.colorHex).opacity(0.30))
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(habit.name)
                        .customFont(.headline, weight: .semibold)

                    if habit.isArchived {
                        Text("habit.status.archived".localized)
                            .customFont(.caption2, weight: .semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.14))
                            .clipShape(.capsule)
                    }
                }

                Text("habit.streak.current".localized(habit.currentStreak))
                    .customFont(.caption)
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
    let progress: Double
    let usesCompactHeader: Bool

    var body: some View {
        switch scope {
        case .week:
            WeeklyStatisticsView(
                habit: habit,
                date: date,
                progress: progress,
                usesCompactHeader: usesCompactHeader
            )
        case .month:
            MonthlyStatisticsView(
                habit: habit,
                date: date,
                progress: progress,
                usesCompactHeader: usesCompactHeader
            )
        case .year:
            YearlyStatisticsView(
                habit: habit,
                date: date,
                progress: progress,
                usesCompactHeader: usesCompactHeader
            )
        }
    }
}

struct StatisticPeriodHeaderView: View {
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
                            .customFont(.subheadline)
                            .fontWeight(.semibold)

                        if habit.isArchived {
                            Text("habit.status.archived".localized)
                                .customFont(.caption2, weight: .semibold)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.secondary.opacity(0.14))
                                .clipShape(.capsule)
                        }
                    }
                }

                Text(title)
                    .customFont(.subheadline)
                    .fontWeight(.semibold)

                if !isCompact {
                    Text(subtitle)
                        .customFont(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct StatisticSummaryTableView: View {
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
            statisticRow(title: "habit.statistics.progress".localized, value: progressText)

            Divider().opacity(0.35)

            statisticRow(title: "habit.statistics.completedDays".localized, value: completedDaysText)

            Divider().opacity(0.35)

            statisticRow(title: "habit.statistics.skippedDays".localized, value: skippedDaysText)

            Divider().opacity(0.35)

            statisticRow(title: "habit.statistics.total".localized, value: totalProgressText)

            Divider().opacity(0.35)

            HStack {
                statisticColumn(title: "habit.statistics.currentStreak".localized, value: "\(habit.currentStreak)")

                Divider().opacity(0.35)

                statisticColumn(title: "habit.statistics.bestStreak".localized, value: "\(habit.longestStreak)")
            }
            .frame(minHeight: 46)
        }
        .padding(.vertical, 2)
    }

    private func statisticRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .customFont(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .customFont(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 32)
    }

    private func statisticColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .customFont(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .customFont(.caption)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WeeklyStatisticsView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    let habit: Habit
    let date: Date
    let progress: Double
    let usesCompactHeader: Bool

    private var weekDates: [Date] {
        viewModel.weekDates(containing: date)
    }

    private var weekTitle: String {
        guard let start = weekDates.first, let end = weekDates.last else {
            return "habit.statistics.selectedWeek".localized
        }

        return "\(start.toString(withFormat: .custom("MMM d")))-\(end.toString(withFormat: .custom("MMM d")))"
    }

    var body: some View {
        let dayStatistics = viewModel.dayStatistics(for: habit, dates: weekDates)

        VStack(alignment: .leading, spacing: 14) {
            StatisticPeriodHeaderView(
                habit: habit,
                progress: progress,
                title: weekTitle,
                subtitle: "habit.statistics.weekProgress".localized,
                isCompact: usesCompactHeader
            )

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weekDates, id: \.self) { day in
                    weekDayColumn(
                        for: day,
                        statistic: dayStatistics[viewModel.calendar.startOfDay(for: day)]
                    )
                }
            }
            .frame(minHeight: 118)
        }
    }

    private func weekDayColumn(
        for day: Date,
        statistic: HabitDayStatistic?
    ) -> some View {
        let isScheduled = statistic?.isScheduled ?? false
        let isSkipped = statistic?.isSkipped ?? false
        let progress = statistic?.progress ?? 0
        let displayHeight = 68.0

        return VStack(spacing: 7) {
            Text(day.toString(withFormat: .dayName(length: 1)))
                .customFont(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Group {
                if isScheduled {
                    if isSkipped {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.cyan.opacity(0.14))
                            .overlay {
                                Image(module: "airplane")
                                    .customFont(.caption, weight: .semibold)
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
                                .customFont(size: 10)
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
                .customFont(.caption2)
                .fontWeight(day.isToday() ? .bold : .regular)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MonthlyStatisticsView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    let habit: Habit
    let date: Date
    let progress: Double
    let usesCompactHeader: Bool

    private let itemSpacing: CGFloat = AppConstant.screenWidth / 40

    private var monthTitle: String {
        date.toString(withFormat: .custom("MMMM yyyy"))
    }

    private var paddedDates: [Date?] {
        guard let firstDate = viewModel.monthDates(containing: date).first else {
            return []
        }

        let weekday = viewModel.calendar.component(.weekday, from: firstDate) - 1
        let leadingEmptyDays = viewModel.orderedWeekdays.firstIndex(of: weekday) ?? 0

        return Array(repeating: nil, count: leadingEmptyDays) + viewModel.monthDates(containing: date).map(Optional.some)
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: itemSpacing), count: 7)
        let dates = paddedDates.compactMap { $0 }
        let dayStatistics = viewModel.dayStatistics(for: habit, dates: dates)

        VStack(alignment: .leading, spacing: 14) {
            StatisticPeriodHeaderView(
                habit: habit,
                progress: progress,
                title: monthTitle,
                subtitle: "habit.statistics.monthProgress".localized,
                isCompact: usesCompactHeader
            )

            LazyVGrid(columns: columns, spacing: itemSpacing) {
                ForEach(viewModel.orderedWeekdays, id: \.self) { weekday in
                    Text(shortWeekdayName(for: weekday))
                        .customFont(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(paddedDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let statistic = dayStatistics[viewModel.calendar.startOfDay(for: date)]
                        let progress = statistic?.progress ?? 0
                        let isScheduled = statistic?.isScheduled ?? false
                        let isSkipped = statistic?.isSkipped ?? false
                        ZStack(alignment: .center) {
                            Group {
                                if isScheduled {
                                    if isSkipped {
                                        Color.cyan.opacity(0.14)
                                            .overlay {
                                                Image(module: "airplane")
                                                    .customFont(size: 10, weight: .semibold)
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
                                                .customFont(size: 10)
                                                .fontWeight(.black)
                                                .foregroundStyle(.tertiary)
                                        }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: itemSpacing))
                            .aspectRatio(1, contentMode: .fit)

                            Text(date.toString(withFormat: .dayNo))
                                .customFont(.caption2)
                                .fontWeight(.semibold)
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
        HabitDateText.weekdayName(for: weekday)
    }
}

struct YearlyStatisticsView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    let habit: Habit
    let date: Date
    let progress: Double
    let usesCompactHeader: Bool

    private let cellSize: CGFloat = 10

    private var yearTitle: String {
        date.toString(withFormat: .custom("yyyy"))
    }

    private var weeks: [[Date]] {
        let calendar = viewModel.calendar
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
        let dayStatistics = viewModel.dayStatistics(for: habit, dates: weeks.flatMap { $0 })

        VStack(alignment: .leading, spacing: 14) {
            StatisticPeriodHeaderView(
                habit: habit,
                progress: progress,
                title: yearTitle,
                subtitle: "habit.statistics.yearProgress".localized,
                isCompact: usesCompactHeader
            )

            AppScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(viewModel.orderedWeekdays, id: \.self) { weekday in
                            Text(shortWeekdayName(for: weekday))
                                .customFont(size: 8, weight: .semibold)
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: cellSize)
                        }
                    }

                    LazyHStack(alignment: .top, spacing: 4) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: 4) {
                                ForEach(week, id: \.self) { date in
                                    contributionCell(
                                        for: date,
                                        statistic: dayStatistics[viewModel.calendar.startOfDay(for: date)]
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func contributionCell(
        for date: Date,
        statistic: HabitDayStatistic?
    ) -> some View {
        let calendar = viewModel.calendar
        let isCurrentYear = calendar.isDate(date, equalTo: self.date, toGranularity: .year)
        let progress = statistic?.progress ?? 0
        let isScheduled = statistic?.isScheduled ?? false
        let isSkipped = statistic?.isSkipped ?? false

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
                            .customFont(size: 2)
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
        HabitDateText.weekdayName(for: weekday, narrow: true)
    }
}
