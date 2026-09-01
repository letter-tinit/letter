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
                if viewModel.isLoading {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("audioBook.speechSettings.loading".localized)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

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
                        Text("audioBook.speechSettings.offline".localized)
                            .tag(SpeechProvider.offline)
                    }
                    .pickerStyle(.inline)
                    .disabled(viewModel.isLoading || viewModel.isSaving)
                }

                if viewModel.selectedProvider == .googleCloud {
                    googleCloudSection(viewModel: viewModel)
                }

                if viewModel.selectedProvider == .offline {
                    offlineSection(viewModel: viewModel)
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

    private func offlineSection(
        viewModel: SpeechProviderSettingsViewModel
    ) -> some View {
        @Bindable var viewModel = viewModel
        return Section {
            Label(
                "audioBook.speechSettings.offline.english".localized,
                systemImage: "waveform"
            )
            AppPicker(
                "audioBook.speechSettings.offline.vietnameseModel".localized,
                selection: $viewModel.selectedOfflineVietnameseModel,
                layout: .control
            ) {
                ForEach(OfflineVietnameseModel.allCases, id: \.self) { model in
                    Text(model.localizedName).tag(model)
                }
            }
            .pickerStyle(.menu)

            if viewModel.isSaving {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("audioBook.speechSettings.offline.preparing".localized)
                        .foregroundStyle(.secondary)
                }
            }

            Label(
                "audioBook.speechSettings.offline.bundled".localized,
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        } footer: {
            Text("audioBook.speechSettings.offline.footer".localized)
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
