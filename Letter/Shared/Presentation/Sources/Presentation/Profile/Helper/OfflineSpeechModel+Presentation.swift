import Domain
import Utility

extension OfflineSpeechModel {
    var localizedName: String {
        switch self {
        case .vieNeuV3Turbo:
            "audioBook.speechSettings.offline.vieNeu".localized
        case .vieNeuV3Nano:
            "audioBook.speechSettings.offline.vieNeuNano".localized
        case .kokoro82M:
            "audioBook.speechSettings.offline.kokoro".localized
        }
    }
}

extension OfflineSpeechVoice {
    var displayName: String {
        switch self {
        case .kokoroHeart: "Heart"
        case .kokoroMichael: "Michael"
        default: rawValue
        }
    }
}

extension BookLanguage {
    static let speechDisplayOrder: [Self] = [.english, .vietnamese]

    static var offlineSpeechDisplayOrder: [Self] {
        speechDisplayOrder.filter { !OfflineSpeechModel.models(for: $0).isEmpty }
    }

    var offlineSpeechLocalizedName: String {
        switch self {
        case .english:
            "audioBook.speechSettings.offline.english".localized
        case .vietnamese:
            "audioBook.speechSettings.offline.vietnamese".localized
        }
    }
}
