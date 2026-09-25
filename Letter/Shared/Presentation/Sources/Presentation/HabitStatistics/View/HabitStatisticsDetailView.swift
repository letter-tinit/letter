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
    @Binding var model: HabitStatisticsScreenModel

    private var displayedHabits: [HabitSnapshot] {
        viewModel.habits.filter {
            viewModel.isVisible($0, scope: model.scope, date: model.date)
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
                            scope: model.scope,
                            date: model.date,
                            usesSimplifiedMode: viewModel.usesCompactStatisticsView
                        )
                    }
                }
            }
            .shadow(color: .primary.opacity(0.3), radius: 3)
        }
    }
}
