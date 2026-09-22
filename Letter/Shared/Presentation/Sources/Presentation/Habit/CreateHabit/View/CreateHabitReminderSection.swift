import SwiftUI
import Domain
import Utility
import Styleguide

struct CreateHabitReminderSection: View {
    @Bindable var viewModel: CreateHabitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("habit.reminder.title".localized)
                    .customFont(.headline)

                Spacer()

                Button {
                    viewModel.addReminder()
                } label: {
                    Image(module: "plus")
                        .fontWeight(.bold)
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("habit.reminder.add".localized)
            }

            if viewModel.reminders.isEmpty {
                Text("habit.reminder.empty".localized)
                    .customFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .appGlassEffect(in: .rect(cornerRadius: 12))
            } else {
                VStack(spacing: 10) {
                    ForEach($viewModel.reminders) { $reminder in
                        row(reminder: $reminder)
                    }
                }
            }

            Text("habit.reminder.repeatHelp".localized)
                .customFont(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func row(reminder: Binding<HabitReminderConfiguration>) -> some View {
        HStack(spacing: 12) {
            Image(module: "bell")
                .customFont(.headline)
                .foregroundStyle(.secondary)

            DatePicker(
                "habit.reminder.time".localized,
                selection: reminder.time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()

            Spacer(minLength: 0)

            Button(role: .destructive) {
                viewModel.deleteReminder(id: reminder.wrappedValue.id)
            } label: {
                Image(module: "trash")
                    .frame(width: 30, height: 30)
            }
            .accessibilityLabel("habit.reminder.delete".localized)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .appGlassEffect(in: .rect(cornerRadius: 12))
    }
}
