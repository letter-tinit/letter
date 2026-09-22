import SwiftUI
import Utility
import Styleguide

struct CreateHabitStyleSection: View {
    @Bindable var viewModel: CreateHabitViewModel
    private let colorOptions = AppConstant.colorOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("habit.style.title".localized)
                .customFont(.headline)

            AppScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Button {
                            viewModel.colorHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            viewModel.colorHex == hex ? Color.primary : Color.clear,
                                            lineWidth: 2
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                        .padding(2)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
