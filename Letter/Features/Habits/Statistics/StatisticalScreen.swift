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
    @State private var title: String = "STATISTICS"
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
                    "No Habits",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Create a habit to view statistics.")
                )
            } else if displayedHabits.isEmpty {
                ContentUnavailableView(
                    "No Active Habits",
                    systemImage: "archivebox",
                    description: Text("Archived habits are hidden.")
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
                .accessibilityLabel(hidesArchivedHabits ? "Show archived habits" : "Hide archived habits")
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
