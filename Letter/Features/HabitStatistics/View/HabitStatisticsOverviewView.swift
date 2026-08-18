//
//  HabitStatisticsOverviewView.swift
//  Letter
//
//  Created by Codex on 26/5/26.
//

import SwiftUI

struct HabitStatisticsOverviewView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    let statisticsScope: StatisticsScope
    let statisticsDate: Date

    private var summary: HabitStatisticSummary {
        habitViewModel.statisticSummary(scope: statisticsScope, containing: statisticsDate)
    }

    private var dates: [Date] {
        habitViewModel.dates(scope: statisticsScope, containing: statisticsDate)
    }

    var body: some View {
        if habitViewModel.habits.isEmpty {
            CommonEmptyView(
                "habit.empty.title".localized,
                systemImage: "chart.bar.xaxis",
                description: "habit.statistics.aggregate.empty.description".localized
            )
        } else {
            AppScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AggregateSummaryCardView(summary: summary)

                    switch statisticsScope {
                    case .week:
                        AggregateWeekChartView(dates: dates)
                    case .month:
                        AggregateMonthChartView(date: statisticsDate)
                    case .year:
                        AggregateYearChartView(date: statisticsDate)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .shadow(color: .primary.opacity(0.3), radius: 3)
        }
    }
}

private struct AggregateSummaryCardView: View {
    let summary: HabitStatisticSummary

    private var progressText: String {
        "\(Int(summary.progress * 100))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                CircularWithTitleProgressView(
                    progress: summary.progress,
                    title: progressText,
                    size: 62,
                    tintColor: .emeraldGreen,
                    fontWeight: .bold
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("habit.statistics.allHabits".localized)
                        .font(.headline)
                        .fontDesign(.rounded)

                    Text("habit.statistics.archivedIncluded".localized)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                statisticRow(title: "habit.statistics.completedDays".localized, value: "\(summary.completedDays)/\(summary.scheduledDays)")
                Divider().opacity(0.35)
                statisticRow(title: "habit.statistics.skippedDays".localized, value: "\(summary.skippedDays)")
                Divider().opacity(0.35)
                statisticRow(title: "habit.statistics.completedCount".localized, value: "\(summary.totalCompletedCount)/\(summary.totalTargetCount)")
            }
        }
        .padding()
        .borderedBackground(cornerRadius: 18)
    }

    private func statisticRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
        }
        .frame(minHeight: 34)
    }
}

private struct AggregateWeekChartView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    let dates: [Date]

    var body: some View {
        let statistics = habitViewModel.aggregateDayStatistics(dates: dates)

        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("habit.statistics.weekProgress".localized)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    weekDayColumn(
                        for: date,
                        statistic: statistics[AppCalendar.current.startOfDay(for: date)]
                    )
                }
            }
            .frame(minHeight: 118)
        }
        .padding()
        .borderedBackground(cornerRadius: 18)
    }

    private func weekDayColumn(
        for date: Date,
        statistic: HabitDayStatistic?
    ) -> some View {
        let progress = statistic?.progress ?? 0
        let isSkippedOnly = statistic?.isSkipped ?? false

        return VStack(spacing: 7) {
            Text(date.toString(withFormat: .dayNameSymbol))
                .font(.caption2.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.secondary)

            Group {
                if isSkippedOnly {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.cyan.opacity(0.14))
                        .overlay {
                            Image(module: "airplane")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.cyan)
                        }
                        .frame(height: 68)
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.emeraldGreen)
                        .opacity(max(progress, 0.05))
                        .frame(height: 68)
                        .scaleEffect(y: max(progress, 0.04), anchor: .bottom)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 2)
            }

            Text(date.toString(withFormat: .dayNo))
                .font(.caption2)
                .fontWeight(date.isToday() ? .bold : .regular)
                .fontDesign(.rounded)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AggregateMonthChartView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    let date: Date

    private let itemSpacing: CGFloat = HabitConstant.screenWidth / 40

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
        let dates = paddedDates.compactMap { $0 }
        let statistics = habitViewModel.aggregateDayStatistics(dates: dates)

        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("habit.statistics.monthProgress".localized)

            LazyVGrid(columns: columns, spacing: itemSpacing) {
                ForEach(habitViewModel.orderedWeekdays, id: \.self) { weekday in
                    Text(shortWeekdayName(for: weekday))
                        .font(.caption.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(paddedDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dateCell(
                            date,
                            statistic: statistics[AppCalendar.current.startOfDay(for: date)]
                        )
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding()
        .borderedBackground(cornerRadius: 18)
    }

    private func dateCell(
        _ date: Date,
        statistic: HabitDayStatistic?
    ) -> some View {
        let progress = statistic?.progress ?? 0
        let isSkippedOnly = statistic?.isSkipped ?? false

        return ZStack {
            if isSkippedOnly {
                RoundedRectangle(cornerRadius: itemSpacing)
                    .fill(Color.cyan.opacity(0.14))

                Image(module: "airplane")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.cyan)
            } else {
                RoundedRectangle(cornerRadius: itemSpacing)
                    .fill(Color.emeraldGreen)
                    .opacity(max(progress, 0.05))

                Text(date.toString(withFormat: .dayNo))
                    .font(.caption2.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary.opacity(progress > 0 ? 1 : 0.45))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: itemSpacing)
                .stroke(Color.primary.opacity(0.1), lineWidth: 2)
        }
    }
}

private struct AggregateYearChartView: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    let date: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("habit.statistics.yearProgress".localized)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...12, id: \.self) { month in
                    monthCell(month)
                }
            }
        }
        .padding()
        .borderedBackground(cornerRadius: 18)
    }

    private func monthCell(_ month: Int) -> some View {
        let calendar = AppCalendar.current
        let year = calendar.component(.year, from: date)
        let monthDate = calendar.date(from: DateComponents(year: year, month: month)) ?? date
        let progress = habitViewModel.statisticSummary(scope: .month, containing: monthDate).progress

        return VStack(spacing: 8) {
            Text(monthDate.toString(withFormat: .custom("MMM")))
                .font(.caption.weight(.semibold))
                .fontDesign(.rounded)

            CircularWithTitleProgressView(
                progress: progress,
                title: "\(Int(progress * 100))%",
                size: 54,
                tintColor: .emeraldGreen,
                fontWeight: .semibold
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private func sectionTitle(_ title: String) -> some View {
    Text(title)
        .font(.headline)
        .fontDesign(.rounded)
}

private func shortWeekdayName(for weekday: Int) -> String {
    HabitDateText.weekdayName(for: weekday)
}

#Preview {
    HabitStatisticsOverviewView(
        statisticsScope: .month,
        statisticsDate: .now
    )
}
