import Foundation

public enum AudioBookDetailFailure: Sendable {
    case bookUnavailable
}

public struct AudioBookDetailState: Sendable {
    public var book: Book?

    public init() {}
}

@MainActor
public protocol AudioBookDetailUseCase: AnyObject {
    var state: AudioBookDetailState { get }
    var onStateChanged: ((AudioBookDetailState) -> Void)? { get set }
    var onFailure: ((AudioBookDetailFailure) -> Void)? { get set }

    func load(bookID: UUID)
}

@MainActor
public final class ImpAudioBookDetailUseCase: AudioBookDetailUseCase {
    private let audioBookUseCase: any AudioBookUseCase

    public private(set) var state = AudioBookDetailState() {
        didSet { onStateChanged?(state) }
    }
    public var onStateChanged: ((AudioBookDetailState) -> Void)?
    public var onFailure: ((AudioBookDetailFailure) -> Void)?

    public init(audioBookUseCase: any AudioBookUseCase) {
        self.audioBookUseCase = audioBookUseCase
    }

    public func load(bookID: UUID) {
        do {
            state.book = try audioBookUseCase.loadBooks().first { $0.id == bookID }
            if state.book == nil { onFailure?(.bookUnavailable) }
        } catch {
            state.book = nil
            onFailure?(.bookUnavailable)
        }
    }

}
