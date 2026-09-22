import SwiftUI
import Domain
import Utility
import Styleguide

/// Replaces the native List row when its sorting status changes, clearing
/// transient swipe state without rebuilding the list or unrelated rows.
struct HabitListRow: View, Identifiable {
    @Environment(HabitRouter.self) private var router
    @Environment(HabitViewModel.self) private var habitViewModel

    @Binding var item: HabitListItem
    @State private var model: HabitItemView.Model

    var id: ID {
        ID(habitID: model.id, completed: model.entryIsCompleted, skipped: model.isSkipped)
    }

    init(item: Binding<HabitListItem>) {
        _item = item
        _model = State(initialValue: HabitItemView.Model(item: item.wrappedValue))
    }

    var body: some View {
        HabitItemView(model: $model)
        .padding(.horizontal)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !model.entryIsCompleted && !model.isSkipped {
                Button {
                    skipHabit()
                } label: {
                    Image(module: "airplane")
                        .tint(.cyan)
                }
            }
        }
        .onChange(of: item) { _, newValue in
            model = HabitItemView.Model(item: newValue)
        }
        .onChange(of: model.isSelected) { _, isSelected in
            guard isSelected else { return }
            showHabitDetail()
            model.isSelected = false
        }
        .onChange(of: model.submittedCompletedCount) { _, completedCount in
            guard let completedCount else { return }
            submitProgress(completedCount)
            model.submittedCompletedCount = nil
        }
        .swipeActions(edge: .trailing) {
            if model.canResetEntry {
                Button {
                    resetHabit()
                } label: {
                    Image(module: "arrow.counterclockwise")
                        .tint(.skyBlue)
                }
            }
        }
    }

    struct ID: Hashable {
        let habitID: UUID
        let completed: Bool
        let skipped: Bool
    }

    private func showHabitDetail() {
        guard let habit = habitViewModel.habit(id: model.id) else { return }
        router.push(.habitDetail(habit.id))
    }

    private func submitProgress(_ value: Int) {
        guard let habit = habitViewModel.habit(id: model.id) else { return }
        let wasCompleted = isCompleted(habit, on: habitViewModel.selectedDate)
        habitViewModel.updateHabitEntry(habit, completedCount: value)
        let didComplete = habitViewModel.habit(id: model.id).map {
            isCompleted($0, on: habitViewModel.selectedDate)
        } ?? false

        if !wasCompleted && didComplete {
            Haptic.success()
            SoundPlayer.done()
        }
    }

    private func resetHabit() {
        guard let habit = habitViewModel.habit(id: model.id) else { return }
        habitViewModel.resetHabitEntry(habit)
    }

    private func skipHabit() {
        guard let habit = habitViewModel.habit(id: model.id) else { return }
        Haptic.selection()
        habitViewModel.skipHabitEntry(habit)
    }

    private func isCompleted(_ habit: HabitSnapshot, on date: Date) -> Bool {
        habit.entries.first {
            habitViewModel.calendar.isDate($0.date, inSameDayAs: date)
        }?.isCompleted(goalCount: habit.goalCount) ?? false
    }
}
