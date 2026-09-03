import SwiftUI
import Domain
import Styleguide

struct SpeechProviderSettingsScreen: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void

    init(onSaved: @escaping () -> Void = {}) {
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                SpeechProviderLoadingSection(isLoading: viewModel.isLoading)
                SpeechProviderPickerSection(
                    selection: $viewModel.selectedProvider,
                    isDisabled: viewModel.isLoading || viewModel.isSaving
                )
                SpeechProviderConfigurationSection(provider: viewModel.selectedProvider)
                SpeechProviderErrorSection(errorMessage: viewModel.errorMessage)
            }
            .navigationTitle("audioBook.speechSettings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized) {
                        Task {
                            guard await viewModel.save() else { return }
                            onSaved()
                            dismiss()
                        }
                    }
                    .disabled(
                        viewModel.isLoading
                            || viewModel.isSaving
                    )
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

}
