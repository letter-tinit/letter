import SwiftUI
import Domain
import Utility
import Styleguide

struct CreateHabitGoalSection: View {
    @Bindable var viewModel: CreateHabitViewModel
    let onStartNewVersion: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("habit.goal.title".localized)
                .customFont(.headline)

            AppPicker(
                "habit.goal.type".localized,
                selection: $viewModel.goalType,
                layout: .control
            ) {
                Text("habit.goal.count".localized).tag(GoalType.count)
                Text("habit.goal.todo".localized).tag(GoalType.todo)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.goalType) { _, newValue in
                if newValue == .todo {
                    viewModel.goalCountText = "1"
                    viewModel.goalUnit = "habit.goal.times".localized
                }
            }
            .disabled(viewModel.locksGoalAndSchedule)

            if viewModel.goalType == .count {
                HStack(spacing: 12) {
                    TextField("habit.goal.target".localized, text: $viewModel.goalCountText)
                        .keyboardType(.numberPad)
                        .disabled(viewModel.goalType == .todo || viewModel.locksGoalAndSchedule)
                        .padding()
                        .appGlassEffect(in: .rect(cornerRadius: 12))

                    TextField("habit.goal.unit".localized, text: $viewModel.goalUnit)
                        .disabled(viewModel.locksGoalAndSchedule)
                        .padding()
                        .appGlassEffect(in: .rect(cornerRadius: 12))
                }
                .transition(.opacity)
            }

            if viewModel.isEditing {
                CreateHabitLockedVersionPrompt(
                    message: "habit.goal.locked".localized,
                    targetVersionNumber: viewModel.targetVersionNumber,
                    onStartNewVersion: onStartNewVersion
                )
            }
        }
    }
}
