import Foundation
import Observation

struct BookImportItem: Identifiable, Equatable {
    enum State: Equatable {
        case indexing
        case failed(String)
    }

    let id: UUID
    let url: URL
    let title: String
    var state: State
}

@Observable
@MainActor
final class AudioBookViewModel {
    private let libraryUseCase: any BookLibraryUseCase
    private let playbackUseCase: any AudioBookPlaybackUseCase
    private var requiresRestartOnResume = false
    private var importWorkerTask: Task<Void, Never>?

    private(set) var books: [Book] = []
    private(set) var importItems: [BookImportItem] = []
    private(set) var voices: [SpeechVoice]
    var selectedVoiceID: String?
    var readingRate = 1.0
    var automaticallyPlaysNextChapter = true
    private(set) var activeBookID: UUID?
    private(set) var activeChapterID: UUID?
    private(set) var currentCharacterOffset = 0
    private(set) var playbackProgress = 0.0
    private(set) var isPlaying = false
    private(set) var isPaused = false
    private(set) var errorMessage: String?

    init(
        libraryUseCase: any BookLibraryUseCase,
        playbackUseCase: any AudioBookPlaybackUseCase
    ) {
        self.libraryUseCase = libraryUseCase
        self.playbackUseCase = playbackUseCase
        voices = playbackUseCase.availableVoices()
        selectedVoiceID = voices.first?.id
        bindPlaybackEvents()
        reloadBooks()
    }

    func reloadBooks() {
        do {
            books = try libraryUseCase.loadBooks()
            errorMessage = nil
        } catch {
            errorMessage = "audioBook.error.library".localized
        }
    }

    func importDocument(from url: URL) {
        importDocuments(from: [url])
    }

    func importDocuments(from urls: [URL]) {
        for url in urls {
            let item = BookImportItem(
                id: UUID(),
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                state: .indexing
            )
            importItems.append(item)
        }
        startImportWorker()
    }

    func retryImport(id: UUID) {
        guard importItems.contains(where: { $0.id == id }) else { return }
        updateImportState(id: id, state: .indexing)
        startImportWorker()
    }

    private func startImportWorker() {
        guard importWorkerTask == nil else { return }
        importWorkerTask = Task { [weak self] in
            guard let self else { return }
            while let item = self.importItems.first(where: {
                if case .indexing = $0.state { return true }
                return false
            }) {
                await self.importItem(item.id)
            }
            self.importWorkerTask = nil
        }
    }

    private func importItem(_ id: UUID) async {
        guard let item = importItems.first(where: { $0.id == id }) else { return }
        let hasScopedAccess = item.url.startAccessingSecurityScopedResource()
        defer { if hasScopedAccess { item.url.stopAccessingSecurityScopedResource() } }
        do {
            let imported = try await libraryUseCase.importBook(from: item.url)
            books.removeAll { $0.id == imported.id }
            books.insert(imported, at: 0)
            importItems.removeAll { $0.id == id }
            errorMessage = nil
        } catch let error as AudioBookError {
            updateImportState(id: id, state: .failed(error.localizedMessage))
        } catch {
            updateImportState(id: id, state: .failed("audioBook.error.import".localized))
        }
    }

    private func updateImportState(id: UUID, state: BookImportItem.State) {
        guard let index = importItems.firstIndex(where: { $0.id == id }) else { return }
        importItems[index].state = state
    }

    func deleteBook(id: UUID) {
        do {
            if activeBookID == id { stop() }
            try libraryUseCase.deleteBook(id: id)
            books.removeAll { $0.id == id }
            errorMessage = nil
        } catch {
            errorMessage = "audioBook.error.delete".localized
        }
    }

    func book(id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    func prepareChapter(bookID: UUID, chapterID: UUID) {
        guard activeBookID != bookID || activeChapterID != chapterID,
              let book = book(id: bookID),
              let chapter = book.chapters.first(where: { $0.id == chapterID }) else { return }
        persistActivePosition()
        playbackUseCase.stop()
        activeBookID = bookID
        activeChapterID = chapterID
        let savedOffset = book.lastPosition?.chapterID == chapterID
            ? book.lastPosition?.characterOffset ?? 0
            : 0
        updateProgress(chapter: chapter, offset: savedOffset)
        isPlaying = false
        isPaused = false
        requiresRestartOnResume = false
        updateChapterNavigationAvailability()
    }

    func play() {
        guard let context = activeContext else { return }
        do {
            try playbackUseCase.play(
                bookTitle: context.book.title,
                chapter: BookChapter(
                    id: context.chapter.id,
                    title: context.chapter.displayTitle,
                    content: context.chapter.content,
                    index: context.chapter.index,
                    groupTitle: context.chapter.groupTitle,
                    role: context.chapter.role
                ),
                from: currentCharacterOffset,
                rate: readingRate,
                voiceID: selectedVoiceID
            )
            requiresRestartOnResume = false
            errorMessage = nil
        } catch {
            errorMessage = "audioBook.error.empty".localized
        }
    }

    func togglePlayback() {
        if isPaused {
            if requiresRestartOnResume {
                play()
            } else {
                playbackUseCase.resume()
            }
        } else if isPlaying {
            pause()
        } else {
            if playbackProgress >= 1 { currentCharacterOffset = 0 }
            play()
        }
    }

    func pause() {
        playbackUseCase.pause()
        persistActivePosition()
    }

    func stop() {
        persistActivePosition()
        playbackUseCase.stop()
        requiresRestartOnResume = false
    }

    func seek(to fraction: Double) {
        guard let context = activeContext else { return }
        let clamped = min(max(fraction, 0), 1)
        updateProgress(
            chapter: context.chapter,
            offset: Int(Double(context.chapter.characterCount) * clamped)
        )
        if isPlaying, !isPaused {
            play()
        } else if isPaused {
            requiresRestartOnResume = true
        }
    }

    func skip(by fraction: Double) {
        seek(to: playbackProgress + fraction)
    }

    func setReadingRate(_ rate: Double) {
        readingRate = min(max(rate, 0.5), 3)
        if isPlaying, !isPaused {
            play()
        } else if isPaused {
            requiresRestartOnResume = true
        }
    }

    var canMoveToPreviousChapter: Bool {
        adjacentChapter(offset: -1) != nil
    }

    var canMoveToNextChapter: Bool {
        adjacentChapter(offset: 1) != nil
    }

    func moveToPreviousChapter() {
        moveToAdjacentChapter(offset: -1, startsPlayback: isPlaying && !isPaused)
    }

    func moveToNextChapter() {
        moveToAdjacentChapter(offset: 1, startsPlayback: isPlaying && !isPaused)
    }

    private var activeContext: (book: Book, chapter: BookChapter)? {
        guard let activeBookID,
              let activeChapterID,
              let book = book(id: activeBookID),
              let chapter = book.chapters.first(where: { $0.id == activeChapterID }) else {
            return nil
        }
        return (book, chapter)
    }

    private func bindPlaybackEvents() {
        playbackUseCase.onProgress = { [weak self] progress in
            guard let self,
                  self.activeChapterID == progress.chapterID,
                  let chapter = self.activeContext?.chapter else { return }
            self.updateProgress(chapter: chapter, offset: progress.characterOffset)
        }
        playbackUseCase.onFinished = { [weak self] in
            guard let self else { return }
            self.persistActivePosition()
            if self.automaticallyPlaysNextChapter {
                self.moveToAdjacentChapter(offset: 1, startsPlayback: true)
            }
        }
        playbackUseCase.onStateChanged = { [weak self] state in
            guard let self else { return }
            switch state {
            case .playing:
                self.isPlaying = true
                self.isPaused = false
            case .paused:
                self.isPlaying = true
                self.isPaused = true
            case .stopped:
                self.isPlaying = false
                self.isPaused = false
            }
        }
        playbackUseCase.onPreviousChapterRequested = { [weak self] in
            self?.moveToAdjacentChapter(offset: -1, startsPlayback: true)
        }
        playbackUseCase.onNextChapterRequested = { [weak self] in
            self?.moveToAdjacentChapter(offset: 1, startsPlayback: true)
        }
    }

    private func updateProgress(chapter: BookChapter, offset: Int) {
        currentCharacterOffset = min(max(offset, 0), chapter.characterCount)
        playbackProgress = chapter.characterCount == 0
            ? 0
            : Double(currentCharacterOffset) / Double(chapter.characterCount)
        guard let activeBookID,
              let index = books.firstIndex(where: { $0.id == activeBookID }) else { return }
        books[index].updatePosition(chapterID: chapter.id, characterOffset: currentCharacterOffset)
    }

    private func persistActivePosition() {
        guard let activeBookID, let activeChapterID else { return }
        try? libraryUseCase.savePosition(
            bookID: activeBookID,
            chapterID: activeChapterID,
            characterOffset: currentCharacterOffset
        )
    }

    private func adjacentChapter(offset: Int) -> BookChapter? {
        guard let context = activeContext,
              let currentIndex = context.book.chapters.firstIndex(where: {
                  $0.id == context.chapter.id
              }) else { return nil }
        let targetIndex = currentIndex + offset
        guard context.book.chapters.indices.contains(targetIndex) else { return nil }
        return context.book.chapters[targetIndex]
    }

    private func moveToAdjacentChapter(offset: Int, startsPlayback: Bool) {
        guard let activeBookID,
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

private extension AudioBookError {
    var localizedMessage: String {
        switch self {
        case .protectedDocument: "audioBook.error.protected".localized
        case .unsupportedFormat: "audioBook.error.format".localized
        case .emptyBook: "audioBook.error.emptyBook".localized
        case .malformedDocument: "audioBook.error.malformed".localized
        case .bookNotFound, .chapterNotFound: "audioBook.error.library".localized
        }
    }
}
