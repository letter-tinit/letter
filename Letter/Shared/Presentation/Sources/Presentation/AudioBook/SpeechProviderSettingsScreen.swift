import SwiftUI
import Domain
import Styleguide

struct SpeechProviderSettingsScreen: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                Section("audioBook.speechSettings.provider".localized) {
                    AppPicker(
                        "audioBook.speechSettings.provider".localized,
                        selection: $viewModel.selectedProvider,
                        layout: .control
                    ) {
                        Text("audioBook.speechSettings.apple".localized)
                            .tag(SpeechProvider.apple)
                        Text("audioBook.speechSettings.google".localized)
                            .tag(SpeechProvider.googleCloud)
                    }
                    .pickerStyle(.inline)
                }

                if viewModel.selectedProvider == .googleCloud {
                    googleCloudSection(viewModel: viewModel)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("audioBook.speechSettings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized) {
                        guard viewModel.save() else { return }
                        onSaved()
                        dismiss()
                    }
                }
            }
            .onAppear { viewModel.reload() }
        }
    }

    private func googleCloudSection(
        viewModel: SpeechProviderSettingsViewModel
    ) -> some View {
        @Bindable var viewModel = viewModel
        return Section {
            AppPicker(
                "audioBook.speechSettings.voice".localized,
                selection: Binding(
                    get: { viewModel.selectedGoogleCloudVoice },
                    set: { viewModel.selectGoogleCloudVoice($0) }
                ),
                layout: .control
            ) {
                ForEach(GoogleCloudVoicePreference.allCases, id: \.self) { voice in
                    Text(voice.localizedName).tag(voice)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(
                    value: Double(viewModel.googleCloudUsage.characterCount),
                    total: Double(viewModel.googleCloudUsage.freeCharacterLimit)
                )
                Text(
                    String(
                        format: "audioBook.speechSettings.usage".localized,
                        viewModel.googleCloudUsage.characterCount,
                        viewModel.googleCloudUsage.freeCharacterLimit
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            SecureField(
                "audioBook.speechSettings.apiKey".localized,
                text: $viewModel.googleCloudAPIKey
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if viewModel.hasGoogleCloudAPIKey {
                Label(
                    "audioBook.speechSettings.keyConfigured".localized,
                    systemImage: "checkmark.shield.fill"
                )
                .foregroundStyle(.green)
                Button("audioBook.speechSettings.removeKey".localized, role: .destructive) {
                    viewModel.removeGoogleCloudCredential()
                }
            }
        } footer: {
            Text("audioBook.speechSettings.security".localized)
        }
    }
}
