//
//  HabitStatisticsDetailView.swift
//  Letter
//
//  Created by TiniT on 21/5/26.
//

import SwiftUI

struct HabitStatisticsDetailView: View {
    @Environment(HabitStatisticsViewModel.self) private var viewModel
    let statisticsScope: StatisticsScope
    let statisticsDate: Date
    @Binding var hidesArchivedHabits: Bool

    private var displayedHabits: [HabitSnapshot] {
        hidesArchivedHabits
        ? viewModel.habits.filter { !$0.isArchived }
        : viewModel.habits
    }

    var body: some View {
        if viewModel.habits.isEmpty {
            CommonEmptyView(
                "habit.empty.title".localized,
                systemImage: "chart.bar.xaxis",
                description: "habit.statistics.empty.description".localized
            )
        } else if displayedHabits.isEmpty {
            CommonEmptyView(
                "habit.statistics.noActive.title".localized,
                systemImage: "archivebox",
                description: "habit.statistics.noActive.description".localized
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

#Preview {
    HabitStatisticsDetailView(
        statisticsScope: .month,
        statisticsDate: .now,
        hidesArchivedHabits: .constant(true)
    )
}
