import Domain
import Utility

extension OfflineVietnameseModel {
    var localizedName: String {
        switch self {
        case .piperVais1000:
            "audioBook.speechSettings.offline.piper".localized
        case .vieNeuV3Turbo:
            "audioBook.speechSettings.offline.vieNeu".localized
        }
    }
}
