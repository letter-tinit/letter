import SwiftUI
import Styleguide

struct CreateHabitFormView: View {
    @Bindable var viewModel: CreateHabitViewModel
    @Binding var showSymbolPicker: Bool
    @Binding var showStartDatePicker: Bool
    @Binding var showEndDatePicker: Bool
    let onStartNewVersion: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.isCreatingVersion {
                CreateHabitVersionContextSection(viewModel: viewModel)
            }

            CreateHabitIdentitySection(
                viewModel: viewModel,
                showSymbolPicker: $showSymbolPicker
            )
            CreateHabitScheduleSection(
                viewModel: viewModel,
                onStartNewVersion: onStartNewVersion
            )
            CreateHabitDurationSection(
                viewModel: viewModel,
                showStartDatePicker: $showStartDatePicker,
                showEndDatePicker: $showEndDatePicker
            )
            CreateHabitGoalSection(
                viewModel: viewModel,
                onStartNewVersion: onStartNewVersion
            )
            CreateHabitReminderSection(viewModel: viewModel)
            CreateHabitStyleSection(viewModel: viewModel)
            CreateHabitPreviewSection(viewModel: viewModel)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 28)
    }
}
