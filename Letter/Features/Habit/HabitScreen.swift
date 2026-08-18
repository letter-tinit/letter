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
                        ForEach(filteredHabits, id: \.id) { habit in
                            HabitItemView(habit: habit, selectedDate: habitViewModel.selectedDate) { action in
                                handleHabitItemAction(action, for: habit)
                            }
                            .padding(.horizontal)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                let entry = habit.entry(for: habitViewModel.selectedDate)
                                if entry?.isCompleted != true && entry?.isSkipped != true {
                                    Button {
                                        skipHabit(habit)
                                    } label: {
                                        Image(module: "airplane")
                                            .tint(.cyan)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if habitViewModel.canResetEntry(for: habit) {
                                    Button {
                                        resetHabit(habit)
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
//                        .fontDesign(.rounded)
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
    
    private func handleHabitItemAction(_ action: HabitItemView.Action, for habit: Habit) {
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
    
    private func resetHabit(_ habit: Habit) {
        habitViewModel.resetHabitEntry(habit)
    }

    private func skipHabit(_ habit: Habit) {
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
