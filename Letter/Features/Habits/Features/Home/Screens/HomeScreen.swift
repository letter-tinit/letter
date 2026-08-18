//
//  HomeScreen.swift
//  Habit
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI

struct HomeScreen: View {
    @State private var progress = 0.6
    @Environment(HomeRouter.self) private var router
    @Environment(HabitStore.self) private var habitStore
    
    var body: some View {
        @Bindable var habitStore = habitStore
        let filteredHabits = habitStore.filteredHabit

        BaseScreen($habitStore.homeTitle) {
            VStack(spacing: 0) {
                WeekView()
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                if filteredHabits.isEmpty {
                    ContentUnavailableView(
                        "No Habits",
                        systemImage: "figure.run.square.stack",
                        description: Text("Create a habit to kick-off your life style")
                    )
                } else {
                    AppList {
                        ForEach(filteredHabits, id: \.id) { habit in
                            HabitItemView(habit: habit, selectedDate: habitStore.selectedDate) { action in
                                handleHabitItemAction(action, for: habit)
                            }
                            .padding(.horizontal)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                let entry = habit.entry(for: habitStore.selectedDate)
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
                                if habitStore.canResetEntry(for: habit) {
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
//                            habitStore.moveFilteredHabits(from: source, to: destination)
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
            habitStore.backToday()
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
            let wasCompleted = habit.entry(for: habitStore.selectedDate)?.isCompleted ?? false
            habitStore.updateHabitEntry(habit, completedCount: value)
            let isCompleted = habit.entry(for: habitStore.selectedDate)?.isCompleted ?? false
            
            if !wasCompleted && isCompleted {
                Haptic.success()
                SoundPlayer.done()
            }
        }
    }
    
    private func resetHabit(_ habit: Habit) {
        habitStore.resetHabitEntry(habit)
    }

    private func skipHabit(_ habit: Habit) {
        Haptic.selection()
        habitStore.skipHabitEntry(habit)
    }
    
    private func showHabitDetail(_ habit: Habit) {
        router.push(.habitDetail(habit.id))
    }
}

#Preview {
    HomeScreen()
}
