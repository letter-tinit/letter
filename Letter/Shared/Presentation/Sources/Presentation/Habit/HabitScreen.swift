//
//  HabitScreen.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI
import Domain
import Core
import Utility
import Styleguide

public struct HabitScreen: View {
    @State private var progress = 0.6
    @AppStorage(AppLanguage.preferenceKey)
    private var languageCode = AppLanguage.vietnamese.rawValue
    @Environment(HabitRouter.self) private var router
    @Environment(HabitViewModel.self) private var habitViewModel
    
    public var body: some View {
        @Bindable var habitViewModel = habitViewModel
        let habitRows = habitViewModel.filteredHabits.map {
            HabitItemView.Model(item: $0)
        }

        BaseScreen($habitViewModel.title) {
            VStack(spacing: 0) {
                WeekView()
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                if habitRows.isEmpty {
                    CommonEmptyView(
                        "habit.empty.title".localized,
                        systemImage: "figure.run.square.stack",
                        description: "habit.empty.description".localized
                    )
                } else {
                    AppList {
                        ForEach(habitRows) { row in
                            HabitItemView(model: row) { action in
                                handleHabitItemAction(action, habitID: row.id)
                            }
                            .padding(.horizontal)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if !row.entryIsCompleted && !row.isSkipped {
                                    Button {
                                        skipHabit(id: row.id)
                                    } label: {
                                        Image(module: "airplane")
                                            .tint(.cyan)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if row.canResetEntry {
                                    Button {
                                        resetHabit(id: row.id)
                                    } label: {
                                        Image(module: "arrow.counterclockwise")
                                            .tint(.skyBlue)
                                    }
                                }
                            }
                        }
                    }
                    // MARK: - List Configure
                    .listRowSpacing(20)
                    .contentMargins(.vertical, 20)
                    .scrollIndicators(.hidden)
                }
            }
        } didTapOnTitle: {
            Haptic.selection()
            habitViewModel.backToday()
        }
        // MARK: - BaseScreen Configure
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptic.impact(.medium)
                    router.push(.createHabit)
                } label: {
                    Image(module: "plus")
                        .fontWeight(.bold)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .onChange(of: languageCode) { _, _ in
            habitViewModel.refreshLocalizedText()
        }
    }
    
    private func handleHabitItemAction(_ action: HabitItemView.Action, habitID: UUID) {
        guard let habit = habitViewModel.habit(id: habitID) else { return }

        switch action {
        case .tapped:
            showHabitDetail(habit)
        case .progressChanged(let value):
            let wasCompleted = isCompleted(habit, on: habitViewModel.selectedDate)
            habitViewModel.updateHabitEntry(habit, completedCount: value)
            let didComplete = habitViewModel.habit(id: habitID).map {
                isCompleted($0, on: habitViewModel.selectedDate)
            } ?? false
            
            if !wasCompleted && didComplete {
                Haptic.success()
                SoundPlayer.done()
            }
        }
    }
    
    private func resetHabit(id: UUID) {
        guard let habit = habitViewModel.habit(id: id) else { return }
        habitViewModel.resetHabitEntry(habit)
    }

    private func skipHabit(id: UUID) {
        guard let habit = habitViewModel.habit(id: id) else { return }
        Haptic.selection()
        habitViewModel.skipHabitEntry(habit)
    }
    
    private func showHabitDetail(_ habit: HabitSnapshot) {
        router.push(.habitDetail(habit.id))
    }

    private func isCompleted(_ habit: HabitSnapshot, on date: Date) -> Bool {
        habit.entries.first {
            habitViewModel.calendar.isDate($0.date, inSameDayAs: date)
        }?.isCompleted(goalCount: habit.goalCount) ?? false
    }
}

