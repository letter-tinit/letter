//
//  HabitScreen.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI

struct HabitScreen: View {
    @State private var progress = 0.6
    @Environment(HabitRouter.self) private var router
    @Environment(HabitViewModel.self) private var habitViewModel
    
    var body: some View {
        @Bindable var habitViewModel = habitViewModel
        let filteredHabits = habitViewModel.filteredHabit
        let habitRows = filteredHabits.map {
            HabitItemView.Model(habit: $0, selectedDate: habitViewModel.selectedDate)
        }

        BaseScreen($habitViewModel.homeTitle) {
            VStack(spacing: 0) {
                WeekView()
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                if filteredHabits.isEmpty {
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
//                        .onMove { source, destination in
//                            habitViewModel.moveFilteredHabits(from: source, to: destination)
//                        }
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
//            ToolbarItem(placement: .topBarLeading) {
//                if !filteredHabits.isEmpty {
//                    EditButton()
//                }
//            }

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
    }
    
    private func handleHabitItemAction(_ action: HabitItemView.Action, habitID: UUID) {
        guard let habit = habitViewModel.habit(id: habitID) else { return }

        switch action {
        case .tapped:
            showHabitDetail(habit)
        case .progressChanged(let value):
            let wasCompleted = habit.entry(for: habitViewModel.selectedDate)?.isCompleted ?? false
            habitViewModel.updateHabitEntry(habit, completedCount: value)
            let isCompleted = habit.entry(for: habitViewModel.selectedDate)?.isCompleted ?? false
            
            if !wasCompleted && isCompleted {
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
    
    private func showHabitDetail(_ habit: Habit) {
        router.push(.habitDetail(habit.id))
    }
}

#Preview {
    HabitScreen()
}
