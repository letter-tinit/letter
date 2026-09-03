import SwiftUI
import Domain
import Styleguide

struct SpeechProviderLoadingSection: View {
    let isLoading: Bool

    var body: some View {
        if isLoading {
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("audioBook.speechSettings.loading".localized)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SpeechProviderPickerSection: View {
    @Binding var selection: SpeechProvider
    let isDisabled: Bool

    var body: some View {
        Section("audioBook.speechSettings.provider".localized) {
            AppPicker(
                "audioBook.speechSettings.provider".localized,
                selection: $selection,
                layout: .control
            ) {
                Text("audioBook.speechSettings.apple".localized).tag(SpeechProvider.apple)
                Text("audioBook.speechSettings.google".localized).tag(SpeechProvider.googleCloud)
                Text("audioBook.speechSettings.offline".localized).tag(SpeechProvider.offline)
            }
            .pickerStyle(.inline)
            .disabled(isDisabled)
        }
    }
}

struct SpeechProviderConfigurationSection: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel
    let provider: SpeechProvider

    var body: some View {
        switch provider {
        case .apple: AppleSpeechVoiceSection()
        case .googleCloud: GoogleCloudVoiceSection()
        case .offline: OfflineSpeechModelSection()
        }
    }
}

struct SpeechProviderErrorSection: View {
    let errorMessage: String?

    var body: some View {
        if let errorMessage {
            Section {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}

struct AppleSpeechVoiceSection: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel

    var body: some View {
        Section {
            ForEach(BookLanguage.offlineSpeechDisplayOrder, id: \.self) { language in
                AppleSpeechVoicePicker(language: language)
            }
        } footer: {
            Text("audioBook.speechSettings.apple.footer".localized)
        }
    }
}

struct AppleSpeechVoicePicker: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel
    let language: BookLanguage

    var body: some View {
        let voices = viewModel.availableAppleVoices[language] ?? []
        LabeledContent {
            AppPicker(
                language.offlineSpeechLocalizedName,
                selection: Binding(
                    get: { viewModel.selectedAppleVoiceID(for: language) },
                    set: { voiceID in
                        guard let voiceID,
                              let voice = voices.first(where: { $0.id == voiceID }) else { return }
                        viewModel.selectAppleVoice(voice)
                    }
                ),
                layout: .control
            ) {
                Text("audioBook.speechSettings.apple.default".localized).tag(String?.none)
                ForEach(voices) { voice in Text(voice.name).tag(Optional(voice.id)) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(voices.isEmpty)
        } label: {
            SpeechLanguageLabel(language: language)
        }
    }
}

struct GoogleCloudVoiceSection: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        Section {
            ForEach(BookLanguage.offlineSpeechDisplayOrder, id: \.self) { language in
                GoogleCloudVoicePicker(language: language)
            }
            GoogleCloudUsageView(usage: viewModel.googleCloudUsage)
            SecureField("audioBook.speechSettings.apiKey".localized, text: $viewModel.googleCloudAPIKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if viewModel.hasGoogleCloudAPIKey {
                Label("audioBook.speechSettings.keyConfigured".localized, systemImage: "checkmark.shield.fill")
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

struct GoogleCloudVoicePicker: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel
    let language: BookLanguage

    var body: some View {
        LabeledContent {
            AppPicker(
                language.offlineSpeechLocalizedName,
                selection: Binding(
                    get: { viewModel.selectedGoogleCloudVoice(for: language) },
                    set: { viewModel.selectGoogleCloudVoice($0, for: language) }
                ),
                layout: .control
            ) {
                ForEach(GoogleCloudVoicePreference.allCases, id: \.self) {
                    Text($0.displayName(for: language)).tag($0)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        } label: {
            SpeechLanguageLabel(language: language)
        }
    }
}

struct GoogleCloudUsageView: View {
    let usage: GoogleCloudSpeechUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(usage.characterCount), total: Double(usage.freeCharacterLimit))
            Text(String(format: "audioBook.speechSettings.usage".localized, usage.characterCount, usage.freeCharacterLimit))
                .customFont(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct OfflineSpeechModelSection: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel

    var body: some View {
        Section {
            ForEach(BookLanguage.offlineSpeechDisplayOrder, id: \.self) { language in
                OfflineSpeechModelPicker(language: language)
            }
            if viewModel.isSaving {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("audioBook.speechSettings.offline.preparing".localized).foregroundStyle(.secondary)
                }
            }
            Label("audioBook.speechSettings.offline.bundled".localized, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } footer: {
            Text("audioBook.speechSettings.offline.footer".localized)
        }
    }
}

struct OfflineSpeechModelPicker: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel
    let language: BookLanguage

    var body: some View {
        let model = viewModel.selectedOfflineModel(for: language)
        LabeledContent {
            AppPicker(
                language.offlineSpeechLocalizedName,
                selection: Binding(
                    get: { viewModel.selectedOfflineModel(for: language) },
                    set: { viewModel.selectOfflineModel($0, for: language) }
                ),
                layout: .control
            ) {
                ForEach(OfflineSpeechModel.models(for: language), id: \.self) {
                    Text($0.localizedName).tag($0)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        } label: {
            SpeechLanguageLabel(language: language)
        }
        if let voice = viewModel.selectedOfflineVoice(for: model) {
            OfflineSpeechVoicePicker(model: model, selection: voice)
        }
    }
}

struct OfflineSpeechVoicePicker: View {
    @Environment(SpeechProviderSettingsViewModel.self) private var viewModel
    let model: OfflineSpeechModel
    let selection: OfflineSpeechVoice

    var body: some View {
        if !model.availableVoices.isEmpty {
            AppPicker(
                "audioBook.speechSettings.voice".localized,
                selection: Binding(
                    get: { selection },
                    set: { viewModel.selectOfflineVoice($0, for: model) }
                ),
                layout: .labeledRow
            ) {
                ForEach(model.availableVoices, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
        }
    }
}

struct SpeechLanguageLabel: View {
    let language: BookLanguage

    var body: some View {
        Label(language.offlineSpeechLocalizedName, systemImage: "waveform")
    }
}
