import SwiftUI
import Domain
import Utility
import Styleguide

struct CreateHabitPreviewSection: View {
    @Bindable var viewModel: CreateHabitViewModel

    var body: some View {
        let emptyItem = previewHabitItem(completedCount: 0)
        let halfItem = previewHabitItem(completedCount: viewModel.goalCount / 2)
        let doneItem = previewHabitItem(completedCount: viewModel.goalCount)

        VStack(alignment: .leading, spacing: 12) {
            Text("habit.preview.title".localized)
                .customFont(.headline)

            Text("habit.status.untracked".localized)
                .customFont(.subheadline)
            HabitItemView(model: .constant(emptyItem))

            if viewModel.goalType == .count && viewModel.goalCount > 1 {
                Text("habit.status.inProgress".localized)
                    .customFont(.subheadline)
                HabitItemView(model: .constant(halfItem))
            }

            Text("common.done".localized)
                .customFont(.subheadline)
            HabitItemView(model: .constant(doneItem))
        }
    }

    private func previewHabitItem(completedCount: Int) -> HabitItemView.Model {
        let safeGoalCount = max(viewModel.goalCount, 1)
        let completionRatio = min(
            Double(completedCount) / Double(safeGoalCount),
            1
        )
        let item = HabitListItem(
            id: UUID(),
            name: viewModel.trimmedName,
            icon: viewModel.icon,
            colorHex: viewModel.colorHex,
            goalType: viewModel.goalType,
            goalCount: safeGoalCount,
            goalUnit: viewModel.trimmedGoalUnit,
            completedCount: completedCount,
            completionRatio: completionRatio,
            isSkipped: false,
            currentStreak: 0,
            longestStreak: 0,
            lastCompletedDate: nil,
            canEditEntry: true,
            canResetEntry: completedCount > 0,
            entryIsCompleted: completedCount >= safeGoalCount
        )

        return HabitItemView.Model(item: item)
    }
}
