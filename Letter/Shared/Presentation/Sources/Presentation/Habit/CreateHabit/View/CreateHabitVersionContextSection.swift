import SwiftUI
import Utility
import Styleguide

struct CreateHabitVersionContextSection: View {
    @Bindable var viewModel: CreateHabitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(module: "arrow.triangle.2.circlepath")
                    .customFont(.headline)
                    .frame(width: 36, height: 36)
                    .borderedBackground(cornerRadius: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text("habit.version.number".localized(viewModel.targetVersionNumber))
                        .customFont(.headline)

                    Text("habit.version.continuesFromNumber".localized(viewModel.sourceVersionNumber ?? 1))
                        .customFont(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                row(
                    title: "habit.version.previousRepeat".localized,
                    value: viewModel.sourceRepeatTitle
                )

                Divider().opacity(0.28)

                row(
                    title: "habit.version.whatHappens".localized,
                    value: "habit.version.behavior".localized
                )
            }

            Text("habit.version.help".localized)
                .customFont(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .borderedBackground(cornerRadius: 16)
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .customFont(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .customFont(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 30)
    }
}
