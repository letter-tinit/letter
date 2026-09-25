import SwiftUI
import Styleguide

struct CreateHabitFormView: View {
    @Bindable var viewModel: CreateHabitViewModel
    @Binding var showSymbolPicker: Bool
    @Binding var showStartDatePicker: Bool
    @Binding var showEndDatePicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CreateHabitIdentitySection(
                viewModel: viewModel,
                showSymbolPicker: $showSymbolPicker
            )
            CreateHabitScheduleSection(viewModel: viewModel)
            CreateHabitDurationSection(
                viewModel: viewModel,
                showStartDatePicker: $showStartDatePicker,
                showEndDatePicker: $showEndDatePicker
            )
            CreateHabitGoalSection(viewModel: viewModel)
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
