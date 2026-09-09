import Foundation
import Observation
import Domain
import Utility
import Styleguide

@Observable
@MainActor
public final class AudioBookDetailViewModel {
    private let useCase: any AudioBookDetailUseCase
    private var state: AudioBookDetailState

    public private(set) var toastMessage: ToastMessage?

    public init(useCase: any AudioBookDetailUseCase) {
        self.useCase = useCase
        state = useCase.state
        useCase.onStateChanged = { [weak self] state in self?.state = state }
        useCase.onFailure = { [weak self] failure in self?.show(failure) }
    }

    public var book: Book? { state.book }

    public func load(bookID: UUID) { useCase.load(bookID: bookID) }

    private func show(_ failure: AudioBookDetailFailure) {
        let message = switch failure {
        case .bookUnavailable: "audioBook.error.library".localized
        }
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}
