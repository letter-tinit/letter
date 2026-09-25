import SwiftUI
import Domain
import Utility
import Styleguide

struct CreateHabitScheduleSection: View {
    @Bindable var viewModel: CreateHabitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("habit.repeat.title".localized)
                .customFont(.headline)

            AppPicker(
                "habit.repeat.title".localized,
                selection: $viewModel.frequency,
                layout: .control
            ) {
                Text("habit.repeat.daily".localized).tag(HabitFrequency.daily)
                Text("habit.repeat.weekday".localized).tag(HabitFrequency.weekday)
                Text("habit.repeat.weekend".localized).tag(HabitFrequency.weekend)
                Text("habit.repeat.custom".localized).tag(HabitFrequency.custom)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.frequency) { _, newValue in
                viewModel.selectFrequency(newValue)
            }
            .onChange(of: viewModel.startDate) { _, newValue in
                if viewModel.hasEndDate &&
                    viewModel.normalizedEndDate < viewModel.startOfDay(for: newValue) {
                    viewModel.endDate = newValue
                }
            }

            HStack(spacing: 8) {
                ForEach(viewModel.orderedWeekdays, id: \.self) { weekday in
                    Button {
                        viewModel.toggleWeekday(weekday)
                    } label: {
                        let tintColor = viewModel.selectedDays.contains(weekday)
                            ? Color.cyan.opacity(0.38)
                            : Color.primary.opacity(0.06)

                        Text(HabitDateText.weekdayName(for: weekday))
                            .customFont(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .foregroundStyle(viewModel.selectedDays.contains(weekday) ? .white : .primary)
                            .appGlassEffect(
                                .regular.tint(tintColor),
                                in: .rect(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
