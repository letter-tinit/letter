import Foundation
import Observation
import Domain
import Utility
import Styleguide

public struct ActiveAudioBookPlayback: Equatable, Sendable {
    public let bookID: UUID
    public let bookTitle: String
    public let chapterID: UUID
    public let chapterTitle: String
    public let chapterCharacterCount: Int

    init(book: Book, chapter: BookChapter) {
        bookID = book.id
        bookTitle = book.title
        chapterID = chapter.id
        chapterTitle = chapter.displayTitle
        chapterCharacterCount = chapter.characterCount
    }
}

@Observable
@MainActor
public final class AudioBookPlayerViewModel {
    private let useCase: any AudioBookPlayerUseCase
    private var state: AudioBookPlayerState

    public private(set) var toastMessage: ToastMessage?

    public init(useCase: any AudioBookPlayerUseCase) {
        self.useCase = useCase
        state = useCase.state
        useCase.onStateChanged = { [weak self] state in
            self?.state = state
        }
        useCase.onFailure = { [weak self] failure in
            self?.show(failure)
        }
    }

    public var readingRate: Double { state.readingRate }
    public var automaticallyPlaysNextChapter: Bool {
        get { state.automaticallyPlaysNextChapter }
        set { useCase.setAutomaticallyPlaysNextChapter(newValue) }
    }
    public var activeBookID: UUID? { state.activeBookID }
    public var activeChapterID: UUID? { state.activeChapterID }
    public var playbackProgress: Double { state.playbackProgress }
    public var isPlaying: Bool { state.isPlaying }
    public var isPaused: Bool { state.isPaused }
    public var canMoveToPreviousChapter: Bool { useCase.canMoveToPreviousChapter }
    public var canMoveToNextChapter: Bool { useCase.canMoveToNextChapter }

    public var activePlayback: ActiveAudioBookPlayback? {
        guard state.isPlaying || state.isPaused,
              let book = activeBook,
              let chapter = activeChapter(in: book) else { return nil }
        return ActiveAudioBookPlayback(book: book, chapter: chapter)
    }

    public func synchronizeLibrary() { useCase.synchronizeLibrary() }
    public func openChapterForViewing(bookID: UUID, chapterID: UUID) {
        useCase.openChapterForViewing(bookID: bookID, chapterID: chapterID)
    }
    public func togglePlayback(bookID: UUID, chapterID: UUID) {
        useCase.togglePlayback(bookID: bookID, chapterID: chapterID)
    }
    public func togglePlayback() { useCase.togglePlayback() }
    public func persistPlaybackCheckpoint() { useCase.persistPlaybackCheckpoint() }
    public func seek(to fraction: Double) { useCase.seek(to: fraction) }
    public func skip(seconds: TimeInterval) { useCase.skip(seconds: seconds) }
    public func setReadingRate(_ rate: Double) { useCase.setReadingRate(rate) }
    public func moveToPreviousChapter() { useCase.moveToPreviousChapter() }
    public func moveToNextChapter() { useCase.moveToNextChapter() }
    public func isActive(bookID: UUID, chapterID: UUID) -> Bool {
        useCase.isActive(bookID: bookID, chapterID: chapterID)
    }
    public func playbackProgress(for book: Book, chapter: BookChapter) -> Double {
        useCase.playbackProgress(for: book, chapter: chapter)
    }

    public func book(id: UUID) -> Book? {
        state.books.first { $0.id == id }
    }

    private var activeBook: Book? {
        guard let activeBookID = state.activeBookID else { return nil }
        return book(id: activeBookID)
    }

    private func activeChapter(in book: Book) -> BookChapter? {
        guard let activeChapterID = state.activeChapterID else { return nil }
        return book.chapters.first { $0.id == activeChapterID }
    }

    private func show(_ failure: AudioBookPlayerFailure) {
        let message: String
        let type: ToastType
        switch failure {
        case .library:
            message = "audioBook.error.library".localized
            type = .failure
        case .emptyChapter:
            message = "audioBook.error.empty".localized
            type = .failure
        case .checkpoint:
            message = "audioBook.error.checkpoint".localized
            type = .failure
        case .speech(let failure):
            switch failure {
            case .googleFreeLimitReached:
                message = "audioBook.error.googleFreeLimit".localized
            case .googleUnavailable:
                message = "audioBook.error.googleFallback".localized
            case .offlineUnavailable:
                message = "audioBook.error.offlineFallback".localized
            case .unavailable:
                message = "audioBook.error.speechProvider".localized
            }
            type = failure == .unavailable ? .failure : .warning
        }
        toastMessage = ToastMessage(text: message, type: type)
    }
}
