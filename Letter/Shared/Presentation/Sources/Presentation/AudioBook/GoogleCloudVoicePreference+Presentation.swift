import Domain
import Utility

extension GoogleCloudVoicePreference {
    var localizedName: String {
        switch self {
        case .femaleOne: "audioBook.voice.femaleOne".localized
        case .femaleTwo: "audioBook.voice.femaleTwo".localized
        case .maleOne: "audioBook.voice.maleOne".localized
        case .maleTwo: "audioBook.voice.maleTwo".localized
        }
    }
}
