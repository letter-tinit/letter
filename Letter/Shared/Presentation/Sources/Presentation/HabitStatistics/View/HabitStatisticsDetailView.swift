//
//  HabitStatisticsDetailView.swift
//  Letter
//
//  Created by TiniT on 21/5/26.
//

import SwiftUI
import Domain
import Utility
import Styleguide

public struct HabitStatisticsDetailView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    public let statisticsScope: StatisticsScope
    public let statisticsDate: Date
    @Binding var hidesArchivedHabits: Bool

    private var displayedHabits: [HabitSnapshot] {
        viewModel.habits.filter {
            (!hidesArchivedHabits || !$0.isArchived) &&
            viewModel.isVisible($0, scope: statisticsScope, date: statisticsDate)
        }
    }

    public var body: some View {
        if viewModel.habits.isEmpty {
            CommonEmptyView(
                "habit.empty.title".localized,
                systemImage: "chart.bar.xaxis",
                description: "habit.statistics.empty.description".localized
            )
        } else if displayedHabits.isEmpty {
            CommonEmptyView(
                "habit.statistics.noRecords.title".localized,
                systemImage: "chart.bar.xaxis",
                description: "habit.statistics.noRecords.description".localized
            )
        } else {
            AppScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(displayedHabits, id: \.id) { habit in
                        StatisticsOverviewView(
                            habit: habit,
                            scope: statisticsScope,
                            date: statisticsDate,
                            usesSimplifiedMode: viewModel.usesCompactStatisticsView
                        )
                    }
                }
            }
            .shadow(color: .primary.opacity(0.3), radius: 3)
        }
    }
}
