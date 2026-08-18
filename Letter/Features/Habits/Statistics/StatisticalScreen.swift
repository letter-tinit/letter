//
//  StatisticalScreen.swift
//  Habit
//
//  Created by TiniT on 21/5/26.
//

import SwiftUI

struct StatisticalScreen: View {
    @Environment(HabitViewModel.self) private var habitViewModel
    @State private var statisticsScope: StatisticsScope = .month
    @State private var statisticsDate: Date = Date()
    @State private var title = "habit.statistics.title".localized
    @State private var hidesArchivedHabits = true

    private var displayedHabits: [Habit] {
        hidesArchivedHabits
        ? habitViewModel.habits.filter { !$0.isArchived }
        : habitViewModel.habits
    }

    var body: some View {
        BaseScreen($title) {
            if habitViewModel.habits.isEmpty {
                ContentUnavailableView(
                    "habit.empty.title".localized,
                    systemImage: "chart.bar.xaxis",
                    description: Text("habit.statistics.empty.description".localized)
                )
            } else if displayedHabits.isEmpty {
                ContentUnavailableView(
                    "habit.statistics.noActive.title".localized,
                    systemImage: "archivebox",
                    description: Text("habit.statistics.noActive.description".localized)
                )
            } else {
                VStack(spacing: 14) {
                    StatisticsTableHeader(
                        scope: $statisticsScope,
                        date: $statisticsDate
                    )
                    .padding(.horizontal)
                    .padding(.top, 14)

                    AppScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(displayedHabits, id: \.id) { habit in
                                StatisticsOverviewView(
                                    habit: habit,
                                    scope: statisticsScope,
                                    date: statisticsDate,
                                    usesSimplifiedMode: habitViewModel.usesCompactStatisticsView
                                )
                            }
                        }
                    }
                }
            }
        }
        .shadow(color: .primary.opacity(0.3), radius: 3)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptic.selection()
                    hidesArchivedHabits.toggle()
                } label: {
                    Image(module: hidesArchivedHabits ? "archivebox.fill" : "archivebox")
                }
                .accessibilityLabel(
                    (hidesArchivedHabits
                     ? "habit.statistics.showArchived"
                     : "habit.statistics.hideArchived").localized
                )
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptic.selection()
                    habitViewModel.usesCompactStatisticsView.toggle()
                } label: {
                    Image(module: habitViewModel.usesCompactStatisticsView ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                }
            }
        }
    }
}

#Preview {
    StatisticalScreen()
}
