import Domain
import Utility

extension OfflineSpeechModel {
    var localizedName: String {
        switch self {
        case .matchaLJSpeech:
            "audioBook.speechSettings.offline.matcha".localized
        case .piperVais1000:
            "audioBook.speechSettings.offline.piper".localized
        case .vieNeuV3Turbo:
            "audioBook.speechSettings.offline.vieNeu".localized
        }
    }
}

extension BookLanguage {
    static let offlineSpeechDisplayOrder: [Self] = [.english, .vietnamese]

    var offlineSpeechLocalizedName: String {
        switch self {
        case .english:
            "audioBook.speechSettings.offline.english".localized
        case .vietnamese:
            "audioBook.speechSettings.offline.vietnamese".localized
        }
    }
}
