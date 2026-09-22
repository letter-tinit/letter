import SwiftUI
import Utility
import Styleguide

struct CreateHabitLockedVersionPrompt: View {
    let message: String
    let targetVersionNumber: Int
    let onStartNewVersion: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .customFont(.footnote)
                .foregroundStyle(.secondary)

            if let onStartNewVersion {
                Button {
                    onStartNewVersion()
                } label: {
                    HStack(spacing: 8) {
                        Image(module: "arrow.triangle.2.circlepath")
                            .customFont(.caption, weight: .semibold)

                        Text("habit.version.start".localized(targetVersionNumber))
                            .customFont(.footnote, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .borderedBackground(cornerRadius: 10)
            }
        }
    }
}

struct CreateHabitDateButton: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(module: "calendar")
                    .customFont(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .customFont(.caption)
                        .foregroundStyle(.secondary)

                    Text(value)
                        .customFont(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 12)
            .appGlassEffect(in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
