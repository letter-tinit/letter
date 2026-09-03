import Domain

public struct SpeechProviderSettingsBackup: Codable {
    public let provider: String
    public let appleVoiceIDs: [String: String]
    public let googleCloudVoices: [String: String]
    public let offlineModels: [String: String]
    public let offlineVoices: [String: String]

    public init(repository: any SpeechProviderSettingsRepository) {
        provider = repository.loadProvider().rawValue
        appleVoiceIDs = Dictionary(uniqueKeysWithValues: BookLanguage.allCases.compactMap { language in
            repository.loadAppleVoiceID(for: language).map { (language.rawValue, $0) }
        })
        googleCloudVoices = Dictionary(uniqueKeysWithValues: BookLanguage.allCases.map { language in
            (language.rawValue, repository.loadGoogleCloudVoice(for: language).rawValue)
        })
        offlineModels = Dictionary(uniqueKeysWithValues: BookLanguage.allCases.map { language in
            (language.rawValue, repository.loadOfflineModel(for: language).rawValue)
        })
        offlineVoices = Dictionary(uniqueKeysWithValues: OfflineSpeechModel.allCases.compactMap { model in
            repository.loadOfflineVoice(for: model).map { (model.rawValue, $0.rawValue) }
        })
    }

    public func restore(to repository: any SpeechProviderSettingsRepository) {
        if let provider = SpeechProvider(rawValue: provider) { repository.saveProvider(provider) }
        for language in BookLanguage.allCases {
            guard let rawLanguage = appleVoiceIDs[language.rawValue] else { continue }
            repository.saveAppleVoiceID(rawLanguage, for: language)
        }
        for language in BookLanguage.allCases {
            if let voice = googleCloudVoices[language.rawValue].flatMap(GoogleCloudVoicePreference.init(rawValue:)) {
                repository.saveGoogleCloudVoice(voice, for: language)
            }
            if let model = offlineModels[language.rawValue].flatMap(OfflineSpeechModel.init(rawValue:)), model.language == language {
                repository.saveOfflineModel(model, for: language)
            }
        }
        for model in OfflineSpeechModel.allCases {
            if let voice = offlineVoices[model.rawValue].map(OfflineSpeechVoice.init(rawValue:)) {
                repository.saveOfflineVoice(voice, for: model)
            }
        }
    }
}
