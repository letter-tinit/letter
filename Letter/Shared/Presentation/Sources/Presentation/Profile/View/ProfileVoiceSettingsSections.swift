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
                Text("audioBook.speechSettings.offline".localized).tag(SpeechProvider.offline)
            }
            .pickerStyle(.inline)
            .disabled(isDisabled)
        }
    }
}

struct SpeechProviderConfigurationSection: View {
    @Environment(ProfileViewModel.self) private var viewModel
    let provider: SpeechProvider

    var body: some View {
        switch provider {
        case .apple: AppleSpeechVoiceSection()
        case .offline: OfflineSpeechModelSection()
        }
    }
}

struct AppleSpeechVoiceSection: View {
    @Environment(ProfileViewModel.self) private var viewModel

    var body: some View {
        Section {
            ForEach(BookLanguage.speechDisplayOrder, id: \.self) { language in
                AppleSpeechVoicePicker(language: language)
            }
        } footer: {
            Text("audioBook.speechSettings.apple.footer".localized)
        }
    }
}

struct AppleSpeechVoicePicker: View {
    @Environment(ProfileViewModel.self) private var viewModel
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

struct OfflineSpeechModelSection: View {
    @Environment(ProfileViewModel.self) private var viewModel

    var body: some View {
        Section {
            ForEach(BookLanguage.offlineSpeechDisplayOrder, id: \.self) { language in
                OfflineSpeechModelPicker(language: language)
            }
            if viewModel.isSavingVoiceSettings {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("audioBook.speechSettings.offline.preparing".localized).foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("audioBook.speechSettings.offline.footer".localized)
        }
    }
}

struct OfflineSpeechModelPicker: View {
    @Environment(ProfileViewModel.self) private var viewModel
    let language: BookLanguage

    var body: some View {
        let model = viewModel.selectedOfflineModel(for: language)
        LabeledContent {
            AppPicker(
                language.offlineSpeechLocalizedName,
                selection: Binding(
                    get: { viewModel.selectedOfflineModel(for: language) },
                    set: { model in
                        if let model { viewModel.selectOfflineModel(model, for: language) }
                    }
                ),
                layout: .control
            ) {
                ForEach(OfflineSpeechModel.models(for: language), id: \.self) {
                    Text($0.localizedName).tag(Optional($0))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        } label: {
            SpeechLanguageLabel(language: language)
        }
        if let model, let voice = viewModel.selectedOfflineVoice(for: model) {
            OfflineSpeechVoicePicker(model: model, selection: voice)
        }
    }
}

struct OfflineSpeechVoicePicker: View {
    @Environment(ProfileViewModel.self) private var viewModel
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
                ForEach(model.availableVoices, id: \.self) { Text($0.displayName).tag($0) }
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
