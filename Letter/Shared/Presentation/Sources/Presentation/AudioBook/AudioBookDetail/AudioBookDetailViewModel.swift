import Foundation
import Observation
import Domain
import Utility
import Styleguide

public struct ExportedAudioFile: Identifiable, Equatable {
    public let url: URL
    public var id: URL { url }
}

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
    public var isExportingAudio: Bool { state.isExportingAudio }
    public var audioExportProgress: Double { state.audioExportProgress }
    public var exportedAudioFile: ExportedAudioFile? {
        state.exportedAudioURL.map(ExportedAudioFile.init)
    }

    public func load(bookID: UUID) { useCase.load(bookID: bookID) }
    public func exportAudio(chapterIDs: Set<UUID>) {
        useCase.exportAudio(chapterIDs: chapterIDs)
    }
    public func cancelAudioExport() { useCase.cancelAudioExport() }
    public func clearExportedAudio() { useCase.clearExportedAudio() }

    private func show(_ failure: AudioBookDetailFailure) {
        let message = switch failure {
        case .bookUnavailable: "audioBook.error.library".localized
        case .exportFailed: "audioBook.export.error".localized
        }
        toastMessage = ToastMessage(text: message, type: .failure)
    }
}
