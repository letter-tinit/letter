//
//  HabitStatisticsOverviewView.swift
//  Letter
//
//  Created by Codex on 26/5/26.
//

import SwiftUI

struct HabitStatisticsOverviewView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    let statisticsScope: StatisticsScope
    let statisticsDate: Date
    
    private var summary: HabitStatisticSummary {
        viewModel.statisticSummary(scope: statisticsScope, containing: statisticsDate)
    }
    
    private var dates: [Date] {
        viewModel.dates(scope: statisticsScope, containing: statisticsDate)
    }
    
    var body: some View {
        if viewModel.habits.isEmpty {
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
                .padding()
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
                        .customFont(.headline, weight: .semibold)
                    
                    Text("habit.statistics.archivedIncluded".localized)
                        .customFont(.caption)
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
        .appGlassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 18)
        )
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
        }
        .frame(minHeight: 34)
    }
}

private struct AggregateWeekChartView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    let dates: [Date]
    
    var body: some View {
        let statistics = viewModel.aggregateDayStatistics(dates: dates)
        
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
        .appGlassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 18)
        )
    }
    
    private func weekDayColumn(
        for date: Date,
        statistic: HabitDayStatistic?
    ) -> some View {
        let progress = statistic?.progress ?? 0
        let isSkippedOnly = statistic?.isSkipped ?? false
        
        return VStack(spacing: 7) {
            Text(date.toString(withFormat: .dayName(length: 1)))
                .customFont(.caption2, weight: .semibold)
                .foregroundStyle(.secondary)
            
            Group {
                if isSkippedOnly {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.cyan.opacity(0.14))
                        .overlay {
                            Image(module: "airplane")
                                .customFont(.caption, weight: .semibold)
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
                .customFont(.caption2)
                .fontWeight(date.isToday() ? .bold : .regular)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AggregateMonthChartView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    let date: Date
    
    private let itemSpacing: CGFloat = HabitConstant.screenWidth / 40
    
    private var paddedDates: [Date?] {
        guard let firstDate = viewModel.monthDates(containing: date).first else {
            return []
        }
        
        let weekday = AppCalendar.current.component(.weekday, from: firstDate) - 1
        let leadingEmptyDays = viewModel.orderedWeekdays.firstIndex(of: weekday) ?? 0
        
        return Array(repeating: nil, count: leadingEmptyDays) + viewModel.monthDates(containing: date).map(Optional.some)
    }

    private var dateRows: [[Date?]] {
        var dates = paddedDates
        let trailingEmptyDays = (7 - dates.count % 7) % 7
        dates.append(contentsOf: Array(repeating: nil, count: trailingEmptyDays))

        return stride(from: 0, to: dates.count, by: 7).map { startIndex in
            Array(dates[startIndex..<(startIndex + 7)])
        }
    }
    
    var body: some View {
        let dates = paddedDates.compactMap { $0 }
        let statistics = viewModel.aggregateDayStatistics(dates: dates)
        
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("habit.statistics.monthProgress".localized)
            
            Grid(horizontalSpacing: itemSpacing, verticalSpacing: itemSpacing) {
                GridRow {
                    ForEach(viewModel.orderedWeekdays, id: \.self) { weekday in
                        Text(shortWeekdayName(for: weekday))
                            .customFont(.caption, weight: .semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                ForEach(Array(dateRows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, date in
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
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .appGlassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 18)
        )
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
                    .customFont(size: 10, weight: .semibold)
                    .foregroundStyle(.cyan)
            } else {
                RoundedRectangle(cornerRadius: itemSpacing)
                    .fill(Color.emeraldGreen)
                    .opacity(max(progress, 0.05))
                
                Text(date.toString(withFormat: .dayNo))
                    .customFont(.caption2, weight: .semibold)
                    .foregroundStyle(.primary.opacity(progress > 0 ? 1 : 0.45))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: itemSpacing)
                .stroke(Color.primary.opacity(0.1), lineWidth: 2)
        }
    }
}

private struct AggregateYearChartView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
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
        .appGlassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 18)
        )
    }
    
    private func monthCell(_ month: Int) -> some View {
        let calendar = AppCalendar.current
        let year = calendar.component(.year, from: date)
        let monthDate = calendar.date(from: DateComponents(year: year, month: month)) ?? date
        let progress = viewModel.statisticSummary(scope: .month, containing: monthDate).progress
        
        return VStack(spacing: 8) {
            Text(monthDate.toString(withFormat: .custom("MMM")))
                .customFont(.caption, weight: .semibold)
            
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
        .customFont(.headline, weight: .semibold)
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
