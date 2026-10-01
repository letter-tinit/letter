import SwiftUI
import Utility
import Styleguide

struct CreateHabitDurationSection: View {
    @Bindable var viewModel: CreateHabitViewModel
    @Binding var showStartDatePicker: Bool
    @Binding var showEndDatePicker: Bool

    private var startDateTitle: String {
        viewModel.startDate.toString(withFormat: .custom("MMM d, yyyy"))
    }

    private var endDateTitle: String {
        viewModel.hasEndDate
            ? viewModel.endDate.toString(withFormat: .custom("MMM d, yyyy"))
            : "habit.duration.noEnd".localized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("habit.duration.title".localized)
                .customFont(.headline)

            HStack(spacing: 12) {
                CreateHabitDateButton(
                    title: "habit.duration.startDate".localized,
                    value: startDateTitle
                ) {
                    showStartDatePicker = true
                }
                .accessibilityIdentifier("habit.form.startDate")
                .accessibilityValue(viewModel.startDate.toString(withFormat: .custom("yyyy-MM-dd")))

                CreateHabitDateButton(
                    title: "habit.duration.endDate".localized,
                    value: endDateTitle
                ) {
                    if !viewModel.hasEndDate {
                        viewModel.endDate = max(viewModel.startDate, Date())
                    }

                    showEndDatePicker = true
                }
                .accessibilityIdentifier("habit.form.endDate")
                .accessibilityValue(viewModel.hasEndDate ? viewModel.endDate.toString(withFormat: .custom("yyyy-MM-dd")) : "none")
            }
        }
    }
}
