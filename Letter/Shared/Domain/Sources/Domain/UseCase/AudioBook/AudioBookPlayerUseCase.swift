import Foundation

public enum AudioBookPlayerFailure: Sendable {
    case library
    case emptyChapter
    case checkpoint
    case speech(SpeechPlaybackFailure)
}

@MainActor
public protocol AudioBookPlaybackRateProviding: AnyObject {
    var readingRate: Double { get }
}

@MainActor
public protocol AudioBookPlayerUseCase: AudioBookPlaybackRateProviding {
    var state: AudioBookPlayerState { get }
    var onStateChanged: ((AudioBookPlayerState) -> Void)? { get set }
    var onFailure: ((AudioBookPlayerFailure) -> Void)? { get set }
    var canMoveToPreviousChapter: Bool { get }
    var canMoveToNextChapter: Bool { get }

    func synchronizeLibrary()
    func openChapterForViewing(bookID: UUID, chapterID: UUID)
    func togglePlayback(bookID: UUID, chapterID: UUID)
    func togglePlayback()
    func persistPlaybackCheckpoint()
    func seek(to fraction: Double)
    func skip(seconds: TimeInterval)
    func setReadingRate(_ rate: Double)
    func setAutomaticallyPlaysNextChapter(_ enabled: Bool)
    func moveToPreviousChapter()
    func moveToNextChapter()
    func isActive(bookID: UUID, chapterID: UUID) -> Bool
    func playbackProgress(for book: Book, chapter: BookChapter) -> Double
}

public struct AudioBookPlayerState: Sendable {
    public var books: [Book] = []
    public var readingRate = 1.0
    public var automaticallyPlaysNextChapter = true
    public var activeBookID: UUID?
    public var activeChapterID: UUID?
    public var currentCharacterOffset = 0
    public var playbackProgress = 0.0
    public var isPlaying = false
    public var isPaused = false

    public init() {}
}

@MainActor
public final class ImpAudioBookPlayerUseCase: AudioBookPlayerUseCase {
    private let libraryUseCase: any AudioBookUseCase
    private let playbackUseCase: any AudioBookPlaybackUseCase
    private let checkpointUseCase: any PlaybackCheckpointUseCase
    private var requiresRestartOnResume = false

    public private(set) var state = AudioBookPlayerState() {
        didSet { onStateChanged?(state) }
    }
    public var onStateChanged: ((AudioBookPlayerState) -> Void)?
    public var onFailure: ((AudioBookPlayerFailure) -> Void)?
    public var readingRate: Double { state.readingRate }

    public init(
        libraryUseCase: any AudioBookUseCase,
        playbackUseCase: any AudioBookPlaybackUseCase,
        checkpointUseCase: any PlaybackCheckpointUseCase
    ) {
        self.libraryUseCase = libraryUseCase
        self.playbackUseCase = playbackUseCase
        self.checkpointUseCase = checkpointUseCase
        bindPlaybackEvents()
        reloadBooks()
    }

    private func reloadBooks() {
        do {
            state.books = try libraryUseCase.loadBooks()
        } catch {
            onFailure?(.library)
        }
    }

    public func synchronizeLibrary() {
        do {
            let books = try libraryUseCase.loadBooks()
            if let activeBookID = state.activeBookID,
               !books.contains(where: { $0.id == activeBookID }) {
                state.activeBookID = nil
                state.activeChapterID = nil
                state.currentCharacterOffset = 0
                state.playbackProgress = 0
                playbackUseCase.stop()
                requiresRestartOnResume = false
            }
            state.books = books
        } catch {
            onFailure?(.library)
        }
    }

    private func book(id: UUID) -> Book? {
        state.books.first { $0.id == id }
    }

    private func prepareChapter(bookID: UUID, chapterID: UUID) {
        guard state.activeBookID != bookID || state.activeChapterID != chapterID,
              let book = book(id: bookID),
              let chapter = book.chapters.first(where: { $0.id == chapterID }) else { return }
        let recordsNewSelection = book.lastPosition?.chapterID != chapterID
        persistActivePosition(force: true)
        playbackUseCase.stop()
        state.activeBookID = bookID
        state.activeChapterID = chapterID
        let savedOffset = checkpointUseCase.savedOffset(for: chapterID, in: book)
        updateProgress(chapter: chapter, offset: savedOffset, recordsCheckpoint: false)
        if recordsNewSelection { persistActivePosition(force: true) }
        state.isPlaying = false
        state.isPaused = false
        requiresRestartOnResume = false
        updateChapterNavigationAvailability()
    }

    /// Opens a chapter for reading without replacing an active audio session.
    public func openChapterForViewing(bookID: UUID, chapterID: UUID) {
        guard !state.isPlaying && !state.isPaused else { return }
        prepareChapter(bookID: bookID, chapterID: chapterID)
    }

    /// The explicit play action is the only action that may replace another chapter's audio.
    public func togglePlayback(bookID: UUID, chapterID: UUID) {
        if state.activeBookID != bookID || state.activeChapterID != chapterID {
            prepareChapter(bookID: bookID, chapterID: chapterID)
        }
        togglePlayback()
    }

    public func isActive(bookID: UUID, chapterID: UUID) -> Bool {
        state.activeBookID == bookID && state.activeChapterID == chapterID
    }

    public func playbackProgress(for book: Book, chapter: BookChapter) -> Double {
        guard !isActive(bookID: book.id, chapterID: chapter.id) else {
            return state.playbackProgress
        }
        let offset = checkpointUseCase.savedOffset(for: chapter.id, in: book)
        return chapter.characterCount == 0
            ? 0
            : Double(offset) / Double(chapter.characterCount)
    }

    private func play() {
        guard let context = activeContext else { return }
        do {
            try playbackUseCase.play(
                bookTitle: context.book.title,
                chapter: BookChapter(
                    id: context.chapter.id,
                    title: context.chapter.title,
                    content: context.chapter.content,
                    index: context.chapter.index,
                    groupTitle: context.chapter.groupTitle,
                    role: context.chapter.role
                ),
                from: state.currentCharacterOffset,
                rate: state.readingRate,
                language: context.book.language
            )
            requiresRestartOnResume = false
        } catch {
            onFailure?(.emptyChapter)
        }
    }

    public func togglePlayback() {
        if state.isPaused {
            if requiresRestartOnResume {
                play()
            } else {
                playbackUseCase.resume()
            }
        } else if state.isPlaying {
            pause()
        } else {
            if state.playbackProgress >= 1, let chapter = activeContext?.chapter {
                updateProgress(chapter: chapter, offset: 0)
            }
            play()
        }
    }

    private func pause() {
        playbackUseCase.pause()
        persistActivePosition(force: true)
    }

    private func stop() {
        persistActivePosition(force: true)
        playbackUseCase.stop()
        requiresRestartOnResume = false
    }

    public func persistPlaybackCheckpoint() {
        persistActivePosition(force: true)
    }

    public func seek(to fraction: Double) {
        guard let context = activeContext else { return }
        updateProgress(
            chapter: context.chapter,
            offset: playbackUseCase.characterOffset(for: fraction, in: context.chapter)
        )
        persistActivePosition(force: true)
        if state.isPlaying, !state.isPaused {
            play()
        } else if state.isPaused {
            requiresRestartOnResume = true
        }
    }

    public func skip(seconds: TimeInterval) {
        if state.isPlaying {
            playbackUseCase.skip(seconds: seconds)
            return
        }
        guard let chapter = activeContext?.chapter, chapter.characterCount > 0 else { return }
        let target = playbackUseCase.skippedCharacterOffset(
            currentOffset: state.currentCharacterOffset,
            seconds: seconds,
            rate: state.readingRate,
            in: chapter
        )
        seek(to: Double(target) / Double(chapter.characterCount))
    }

    public func setReadingRate(_ rate: Double) {
        state.readingRate = playbackUseCase.normalizedRate(rate)
        persistActivePosition(force: true)
        if state.isPlaying, !state.isPaused {
            play()
        } else if state.isPaused {
            requiresRestartOnResume = true
        }
    }

    public func setAutomaticallyPlaysNextChapter(_ enabled: Bool) {
        state.automaticallyPlaysNextChapter = enabled
    }

    public var canMoveToPreviousChapter: Bool {
        adjacentChapter(offset: -1) != nil
    }

    public var canMoveToNextChapter: Bool {
        adjacentChapter(offset: 1) != nil
    }

    public func moveToPreviousChapter() {
        moveToAdjacentChapter(offset: -1, startsPlayback: state.isPlaying && !state.isPaused)
    }

    public func moveToNextChapter() {
        moveToAdjacentChapter(offset: 1, startsPlayback: state.isPlaying && !state.isPaused)
    }

    private var activeContext: (book: Book, chapter: BookChapter)? {
        guard let activeBookID = state.activeBookID,
              let activeChapterID = state.activeChapterID,
              let book = book(id: activeBookID),
              let chapter = book.chapters.first(where: { $0.id == activeChapterID }) else {
            return nil
        }
        return (book, chapter)
    }

    private func bindPlaybackEvents() {
        playbackUseCase.onProgress = { [weak self] progress in
            guard let self,
                  self.state.activeChapterID == progress.chapterID,
                  let chapter = self.activeContext?.chapter else { return }
            self.updateProgress(chapter: chapter, offset: progress.characterOffset)
        }
        playbackUseCase.onFinished = { [weak self] in
            guard let self else { return }
            self.persistActivePosition(force: true)
            if self.state.automaticallyPlaysNextChapter {
                self.moveToAdjacentChapter(offset: 1, startsPlayback: true)
            }
        }
        playbackUseCase.onStateChanged = { [weak self] state in
            guard let self else { return }
            switch state {
            case .playing:
                self.state.isPlaying = true
                self.state.isPaused = false
            case .paused:
                self.state.isPlaying = true
                self.state.isPaused = true
                self.persistActivePosition(force: true)
            case .stopped:
                self.state.isPlaying = false
                self.state.isPaused = false
                self.persistActivePosition(force: true)
            }
        }
        playbackUseCase.onPreviousChapterRequested = { [weak self] in
            self?.moveToAdjacentChapter(offset: -1, startsPlayback: true)
        }
        playbackUseCase.onNextChapterRequested = { [weak self] in
            self?.moveToAdjacentChapter(offset: 1, startsPlayback: true)
        }
        playbackUseCase.onFailure = { [weak self] failure in
            self?.onFailure?(.speech(failure))
        }
    }

    private func updateProgress(
        chapter: BookChapter,
        offset: Int,
        recordsCheckpoint: Bool = true
    ) {
        state.currentCharacterOffset = min(max(offset, 0), chapter.characterCount)
        state.playbackProgress = chapter.characterCount == 0
            ? 0
            : Double(state.currentCharacterOffset) / Double(chapter.characterCount)
        guard let activeBookID = state.activeBookID,
              let index = state.books.firstIndex(where: { $0.id == activeBookID }) else { return }
        state.books[index].updatePlaybackPosition(
            chapterID: chapter.id,
            characterOffset: state.currentCharacterOffset
        )
        if recordsCheckpoint { persistActivePosition(force: false) }
    }

    private func persistActivePosition(force: Bool) {
        guard let activeBookID = state.activeBookID,
              let activeChapterID = state.activeChapterID,
              let book = book(id: activeBookID) else { return }
        do {
            let checkpoint = try checkpointUseCase.recordProgress(
                in: book,
                chapterID: activeChapterID,
                characterOffset: state.currentCharacterOffset,
                rateMultiplier: state.readingRate,
                force: force
            )
            apply(checkpoint, to: activeBookID)
        } catch {
            onFailure?(.checkpoint)
        }
    }

    private func apply(_ checkpoint: BookPlaybackCheckpoint, to bookID: UUID) {
        guard let index = state.books.firstIndex(where: { $0.id == bookID }) else { return }
        state.books[index].updatePlaybackPosition(
            chapterID: checkpoint.position.chapterID,
            characterOffset: checkpoint.position.characterOffset
        )
        guard let furthest = checkpoint.furthestPosition else { return }
        state.books[index].updateFurthestPosition(
            chapterID: furthest.chapterID,
            characterOffset: furthest.characterOffset
        )
    }

    private func adjacentChapter(offset: Int) -> BookChapter? {
        guard let context = activeContext else { return nil }
        guard let currentIndex = context.book.chapters.firstIndex(where: {
            $0.id == context.chapter.id
        }) else { return nil }
        let targetIndex = currentIndex + offset
        guard context.book.chapters.indices.contains(targetIndex) else { return nil }
        return context.book.chapters[targetIndex]
    }

    private func moveToAdjacentChapter(offset: Int, startsPlayback: Bool) {
        guard let activeBookID = state.activeBookID,
              let chapter = adjacentChapter(offset: offset) else { return }
        prepareChapter(bookID: activeBookID, chapterID: chapter.id)
        if startsPlayback { play() }
    }

    private func updateChapterNavigationAvailability() {
        playbackUseCase.setChapterNavigation(
            previousEnabled: canMoveToPreviousChapter,
            nextEnabled: canMoveToNextChapter
        )
    }

}
