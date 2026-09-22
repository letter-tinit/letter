import SwiftUI
import Utility
import Styleguide

struct CreateHabitIdentitySection: View {
    @Bindable var viewModel: CreateHabitViewModel
    @Binding var showSymbolPicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("habit.form.identity".localized)
                .customFont(.headline)

            TextField("habit.form.name".localized, text: $viewModel.name)
                .textInputAutocapitalization(.words)
                .padding()
                .appGlassEffect(
                    .regular,
                    in: .rect(cornerRadius: 12)
                )

            HStack(spacing: 12) {
                Button {
                    baseAnimation {
                        showSymbolPicker = true
                    }
                } label: {
                    Image(module: viewModel.icon)
                        .resizable()
                        .padding()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundStyle(Color(hex: viewModel.colorHex))
                        .appGlassEffect(
                            .regular,
                            in: .rect(cornerRadius: 12)
                        )
                }

                TextField("habit.form.description".localized, text: $viewModel.habitDescription)
                    .frame(height: 60)
                    .padding(.horizontal)
                    .appGlassEffect(
                        .regular,
                        in: .rect(cornerRadius: 12)
                    )
            }
        }
    }
}
