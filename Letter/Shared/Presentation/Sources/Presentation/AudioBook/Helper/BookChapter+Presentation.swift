import Foundation
import Domain
import Utility
import Styleguide

extension BookChapter {
    public var displayTitle: String {
        switch role {
        case .copyright:
            "audioBook.section.copyright".localized
        case .publicationInfo:
            "audioBook.section.publicationInfo".localized
        case .supplementary:
            title.isEmpty ? "audioBook.section.supplementary".localized : title
        case nil:
            title
        }
    }
}
