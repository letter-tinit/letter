import Foundation
import Observation
import Domain
import Utility
import Styleguide

public struct BookImportItem: Identifiable, Equatable {
    public enum State: Equatable {
        case indexing
        case failed(String)
    }

    public let id: UUID
    public let url: URL
    public let title: String
    public var state: State
}

public struct ExportedAudioFile: Identifiable, Equatable {
    public let url: URL
    public var id: URL { url }
}

@Observable
@MainActor
public final class AudioBookViewModel {
    private let libraryUseCase: any BookLibraryUseCase
    private let playbackUseCase: any AudioBookPlaybackUseCase
    private let exportUseCase: any AudioBookExportUseCase
    private let checkpointUseCase: any PlaybackCheckpointUseCase
    private var requiresRestartOnResume = false
    private var exportTask: Task<Void, Never>?
    private var activeAudioExportID: UUID?

    private(set) var books: [Book] = []
    private(set) var importItems: [BookImportItem] = []
    public var readingRate = 1.0
    public var automaticallyPlaysNextChapter = true
    private(set) var activeBookID: UUID?
    private(set) var activeChapterID: UUID?
    private(set) var currentCharacterOffset = 0
    private(set) var playbackProgress = 0.0
    private(set) var isPlaying = false
    private(set) var isPaused = false
    private(set) var isExportingAudio = false
    private(set) var audioExportProgress = 0.0
    private(set) var exportedAudioFile: ExportedAudioFile?
    private(set) var audioExportErrorMessage: String?
    private(set) var errorMessage: String?

    public init(
        libraryUseCase: any BookLibraryUseCase,
        playbackUseCase: any AudioBookPlaybackUseCase,
        exportUseCase: any AudioBookExportUseCase,
        checkpointUseCase: any PlaybackCheckpointUseCase
    ) {
        self.libraryUseCase = libraryUseCase
        self.playbackUseCase = playbackUseCase
        self.exportUseCase = exportUseCase
        self.checkpointUseCase = checkpointUseCase
        bindPlaybackEvents()
        reloadBooks()
    }

    public func reloadBooks() {
        do {
            books = try libraryUseCase.loadBooks()
            errorMessage = nil
        } catch {
            errorMessage = "audioBook.error.library".localized
        }
    }

    public func importDocument(from url: URL) {
        importDocuments(from: [url])
    }

    public func importDocuments(from urls: [URL]) {
        for url in urls {
            let item = BookImportItem(
                id: UUID(),
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                state: .indexing
            )
            importItems.append(item)
            Task { await importItem(item.id) }
        }
    }

    public func retryImport(id: UUID) {
        guard importItems.contains(where: { $0.id == id }) else { return }
        updateImportState(id: id, state: .indexing)
        Task { await importItem(id) }
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

    public func deleteBook(id: UUID) {
        do {
            if activeBookID == id { stop() }
            try libraryUseCase.deleteBook(id: id)
            books.removeAll { $0.id == id }
            errorMessage = nil
        } catch {
            errorMessage = "audioBook.error.delete".localized
        }
    }

    public func book(id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    public func exportBookAudio(bookID: UUID, chapterIDs: Set<UUID>) {
        guard let book = book(id: bookID), !isExportingAudio else { return }
        clearExportedAudio()
        isExportingAudio = true
        audioExportProgress = 0
        audioExportErrorMessage = nil
        let exportID = UUID()
        activeAudioExportID = exportID
        exportTask = Task { [weak self] in
            await self?.performAudioExport(
                book: book,
                chapterIDs: chapterIDs,
                exportID: exportID
            )
        }
    }

    private func performAudioExport(
        book: Book,
        chapterIDs: Set<UUID>,
        exportID: UUID
    ) async {
        do {
            let url = try await exportUseCase.export(
                book: book,
                chapterIDs: chapterIDs,
                rate: readingRate
            ) { [weak self] progress in
                guard self?.activeAudioExportID == exportID else { return }
                self?.audioExportProgress = progress
            }
            guard activeAudioExportID == exportID else {
                exportUseCase.discardExport(at: url)
                return
            }
            audioExportProgress = 1
            exportedAudioFile = ExportedAudioFile(url: url)
            audioExportErrorMessage = nil
        } catch is CancellationError {
            if activeAudioExportID == exportID { audioExportErrorMessage = nil }
        } catch {
            if activeAudioExportID == exportID {
                audioExportErrorMessage = "audioBook.export.error".localized
            }
        }
        finishAudioExport(id: exportID)
    }

    private func finishAudioExport(id: UUID) {
        guard activeAudioExportID == id else { return }
        activeAudioExportID = nil
        isExportingAudio = false
        exportTask = nil
    }

    public func cancelAudioExport() {
        exportTask?.cancel()
        exportUseCase.cancel()
        activeAudioExportID = nil
        exportTask = nil
        isExportingAudio = false
        audioExportProgress = 0
        audioExportErrorMessage = nil
    }

    public func clearExportedAudio() {
        guard let exportedAudioFile else { return }
        exportUseCase.discardExport(at: exportedAudioFile.url)
        self.exportedAudioFile = nil
    }

    public func prepareChapter(bookID: UUID, chapterID: UUID) {
        guard activeBookID != bookID || activeChapterID != chapterID,
              let book = book(id: bookID),
              let chapter = book.chapters.first(where: { $0.id == chapterID }) else { return }
        let recordsNewSelection = book.lastPosition?.chapterID != chapterID
        persistActivePosition(force: true)
        playbackUseCase.stop()
        activeBookID = bookID
        activeChapterID = chapterID
        let savedOffset = savedOffset(for: chapterID, in: book)
        updateProgress(chapter: chapter, offset: savedOffset, recordsCheckpoint: false)
        if recordsNewSelection { persistActivePosition(force: true) }
        isPlaying = false
        isPaused = false
        requiresRestartOnResume = false
        updateChapterNavigationAvailability()
    }

    public func play() {
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
                language: context.book.language
            )
            requiresRestartOnResume = false
            errorMessage = nil
        } catch {
            errorMessage = "audioBook.error.empty".localized
        }
    }

    public func togglePlayback() {
        if isPaused {
            if requiresRestartOnResume {
                play()
            } else {
                playbackUseCase.resume()
            }
        } else if isPlaying {
            pause()
        } else {
            if playbackProgress >= 1, let chapter = activeContext?.chapter {
                updateProgress(chapter: chapter, offset: 0)
            }
            play()
        }
    }

    public func pause() {
        playbackUseCase.pause()
        persistActivePosition(force: true)
    }

    public func stop() {
        persistActivePosition(force: true)
        playbackUseCase.stop()
        requiresRestartOnResume = false
    }

    public func persistPlaybackCheckpoint() {
        persistActivePosition(force: true)
    }

    public func seek(to fraction: Double) {
        guard let context = activeContext else { return }
        let clamped = min(max(fraction, 0), 1)
        updateProgress(
            chapter: context.chapter,
            offset: Int(Double(context.chapter.characterCount) * clamped)
        )
        persistActivePosition(force: true)
        if isPlaying, !isPaused {
            play()
        } else if isPaused {
            requiresRestartOnResume = true
        }
    }

    public func skip(by fraction: Double) {
        seek(to: playbackProgress + fraction)
    }

    public func skip(seconds: TimeInterval) {
        if isPlaying {
            playbackUseCase.skip(seconds: seconds)
            return
        }
        guard let chapter = activeContext?.chapter, chapter.characterCount > 0 else { return }
        let characterDelta = Int(seconds * 14 * readingRate)
        let target = min(max(currentCharacterOffset + characterDelta, 0), chapter.characterCount)
        seek(to: Double(target) / Double(chapter.characterCount))
    }

    public func setReadingRate(_ rate: Double) {
        let clamped = min(max(rate, 0.5), 3)
        readingRate = (clamped * 4).rounded() / 4
        persistActivePosition(force: true)
        if isPlaying, !isPaused {
            play()
        } else if isPaused {
            requiresRestartOnResume = true
        }
    }

    public func speechVoiceDidChange() {
        persistActivePosition(force: true)
        if isPlaying, !isPaused {
            play()
        } else if isPaused {
            requiresRestartOnResume = true
        }
    }

    public var canMoveToPreviousChapter: Bool {
        adjacentChapter(offset: -1) != nil
    }

    public var canMoveToNextChapter: Bool {
        adjacentChapter(offset: 1) != nil
    }

    public func moveToPreviousChapter() {
        moveToAdjacentChapter(offset: -1, startsPlayback: isPlaying && !isPaused)
    }

    public func moveToNextChapter() {
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
            self.persistActivePosition(force: true)
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
                self.persistActivePosition(force: true)
            case .stopped:
                self.isPlaying = false
                self.isPaused = false
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
            switch failure {
            case .googleFreeLimitReached:
                self?.errorMessage = "audioBook.error.googleFreeLimit".localized
            case .googleUnavailable:
                self?.errorMessage = "audioBook.error.googleFallback".localized
            case .offlineUnavailable:
                self?.errorMessage = "audioBook.error.offlineFallback".localized
            case .unavailable:
                self?.errorMessage = "audioBook.error.speechProvider".localized
            }
        }
    }

    private func updateProgress(
        chapter: BookChapter,
        offset: Int,
        recordsCheckpoint: Bool = true
    ) {
        currentCharacterOffset = min(max(offset, 0), chapter.characterCount)
        playbackProgress = chapter.characterCount == 0
            ? 0
            : Double(currentCharacterOffset) / Double(chapter.characterCount)
        guard let activeBookID,
              let index = books.firstIndex(where: { $0.id == activeBookID }) else { return }
        books[index].updatePlaybackPosition(
            chapterID: chapter.id,
            characterOffset: currentCharacterOffset
        )
        if recordsCheckpoint { persistActivePosition(force: false) }
    }

    private func persistActivePosition(force: Bool) {
        guard let activeBookID,
              let activeChapterID,
              let book = book(id: activeBookID) else { return }
        do {
            let checkpoint = try checkpointUseCase.recordProgress(
                in: book,
                chapterID: activeChapterID,
                characterOffset: currentCharacterOffset,
                rateMultiplier: readingRate,
                force: force
            )
            apply(checkpoint, to: activeBookID)
        } catch {
            errorMessage = "audioBook.error.checkpoint".localized
        }
    }

    private func apply(_ checkpoint: BookPlaybackCheckpoint, to bookID: UUID) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[index].updatePlaybackPosition(
            chapterID: checkpoint.position.chapterID,
            characterOffset: checkpoint.position.characterOffset
        )
        guard let furthest = checkpoint.furthestPosition else { return }
        books[index].updateFurthestPosition(
            chapterID: furthest.chapterID,
            characterOffset: furthest.characterOffset
        )
    }

    private func savedOffset(for chapterID: UUID, in book: Book) -> Int {
        if book.lastPosition?.chapterID == chapterID {
            return book.lastPosition?.characterOffset ?? 0
        }
        if book.furthestPosition?.chapterID == chapterID {
            return book.furthestPosition?.characterOffset ?? 0
        }
        return 0
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

extension AudioBookError {
    public var localizedMessage: String {
        switch self {
        case .protectedDocument: "audioBook.error.protected".localized
        case .unsupportedFormat: "audioBook.error.format".localized
        case .emptyBook: "audioBook.error.emptyBook".localized
        case .malformedDocument: "audioBook.error.malformed".localized
        case .chapterNotFound: "audioBook.error.library".localized
        }
    }
}
