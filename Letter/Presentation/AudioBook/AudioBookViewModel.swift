import Foundation
import Observation

@Observable
@MainActor
final class AudioBookViewModel {
    private let bookUseCase: any BookUseCase
    private let audioBookUseCase: any AudioBookUseCase

    var text = ""
    private(set) var documentName: String?
    private(set) var isPlaying = false
    private(set) var isPaused = false
    private(set) var errorMessage: String?

    init(
        bookUseCase: any BookUseCase,
        audioBookUseCase: any AudioBookUseCase
    ) {
        self.bookUseCase = bookUseCase
        self.audioBookUseCase = audioBookUseCase
    }

    func importDocument(from url: URL) {
        do {
            let book = try bookUseCase.importBook(from: url)
            text = book.content
            documentName = book.title
            errorMessage = nil
            isPlaying = false
            isPaused = false
        } catch {
            errorMessage = "audioBook.error.import".localized
        }
    }

    func speak() {
        do {
            try audioBookUseCase.speak(text: text)
            isPlaying = true
            isPaused = false
            errorMessage = nil
        } catch {
            errorMessage = "audioBook.error.empty".localized
        }
    }

    func pause() {
        audioBookUseCase.pause()
        isPaused = true
    }

    func resume() {
        audioBookUseCase.resume()
        isPaused = false
    }

    func stop() {
        audioBookUseCase.stop()
        isPlaying = false
        isPaused = false
    }
}
