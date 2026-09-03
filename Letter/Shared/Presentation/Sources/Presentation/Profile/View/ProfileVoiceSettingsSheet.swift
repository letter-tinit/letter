import SwiftUI
import Domain
import Styleguide

struct ProfileVoiceSettingsSheet: View {
    @Environment(ProfileViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void

    init(onSaved: @escaping () -> Void = {}) {
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                SpeechProviderLoadingSection(isLoading: viewModel.isLoadingVoiceSettings)
                SpeechProviderPickerSection(
                    selection: $viewModel.selectedProvider,
                    isDisabled: viewModel.isLoadingVoiceSettings || viewModel.isSavingVoiceSettings
                )
                SpeechProviderConfigurationSection(provider: viewModel.selectedProvider)
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
                            guard await viewModel.saveVoiceSettings() else { return }
                            onSaved()
                            dismiss()
                        }
                    }
                    .disabled(
                        viewModel.isLoadingVoiceSettings
                            || viewModel.isSavingVoiceSettings
                    )
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .toast(message: viewModel.toastMessage)
        .task { await viewModel.reloadVoiceSettings() }
    }

}
