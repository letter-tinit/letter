import Foundation

public enum AudioBookDetailFailure: Sendable {
    case bookUnavailable
    case exportFailed
}

public struct AudioBookDetailState: Sendable {
    public var book: Book?
    public var isExportingAudio = false
    public var audioExportProgress = 0.0
    public var exportedAudioURL: URL?

    public init() {}
}

@MainActor
public protocol AudioBookDetailUseCase: AnyObject {
    var state: AudioBookDetailState { get }
    var onStateChanged: ((AudioBookDetailState) -> Void)? { get set }
    var onFailure: ((AudioBookDetailFailure) -> Void)? { get set }

    func load(bookID: UUID)
    func exportAudio(chapterIDs: Set<UUID>)
    func cancelAudioExport()
    func clearExportedAudio()
}

@MainActor
public final class ImpAudioBookDetailUseCase: AudioBookDetailUseCase {
    private let audioBookUseCase: any AudioBookUseCase
    private let exportUseCase: any AudioBookExportUseCase
    private let playbackRateProvider: any AudioBookPlaybackRateProviding
    private var exportTask: Task<Void, Never>?
    private var activeExportID: UUID?

    public private(set) var state = AudioBookDetailState() {
        didSet { onStateChanged?(state) }
    }
    public var onStateChanged: ((AudioBookDetailState) -> Void)?
    public var onFailure: ((AudioBookDetailFailure) -> Void)?

    public init(
        audioBookUseCase: any AudioBookUseCase,
        exportUseCase: any AudioBookExportUseCase,
        playbackRateProvider: any AudioBookPlaybackRateProviding
    ) {
        self.audioBookUseCase = audioBookUseCase
        self.exportUseCase = exportUseCase
        self.playbackRateProvider = playbackRateProvider
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

    public func exportAudio(chapterIDs: Set<UUID>) {
        guard let book = state.book, !state.isExportingAudio else { return }
        clearExportedAudio()
        state.isExportingAudio = true
        state.audioExportProgress = 0
        let exportID = UUID()
        activeExportID = exportID
        exportTask = Task { [weak self] in
            await self?.performExport(
                book: book,
                chapterIDs: chapterIDs,
                exportID: exportID
            )
        }
    }

    public func cancelAudioExport() {
        exportTask?.cancel()
        exportUseCase.cancel()
        activeExportID = nil
        exportTask = nil
        state.isExportingAudio = false
        state.audioExportProgress = 0
    }

    public func clearExportedAudio() {
        guard let url = state.exportedAudioURL else { return }
        exportUseCase.discardExport(at: url)
        state.exportedAudioURL = nil
    }

    private func performExport(
        book: Book,
        chapterIDs: Set<UUID>,
        exportID: UUID
    ) async {
        do {
            let url = try await exportUseCase.export(
                book: book,
                chapterIDs: chapterIDs,
                rate: playbackRateProvider.readingRate
            ) { [weak self] progress in
                guard self?.activeExportID == exportID else { return }
                self?.state.audioExportProgress = progress
            }
            guard activeExportID == exportID else {
                exportUseCase.discardExport(at: url)
                return
            }
            state.audioExportProgress = 1
            state.exportedAudioURL = url
        } catch is CancellationError {
            // Cancellation is an explicit user action.
        } catch {
            onFailure?(.exportFailed)
        }
        finishExport(id: exportID)
    }

    private func finishExport(id: UUID) {
        guard activeExportID == id else { return }
        activeExportID = nil
        exportTask = nil
        state.isExportingAudio = false
    }
}
