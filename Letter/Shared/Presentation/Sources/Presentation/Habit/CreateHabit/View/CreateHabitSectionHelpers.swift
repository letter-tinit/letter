import SwiftUI
import Utility
import Styleguide

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
