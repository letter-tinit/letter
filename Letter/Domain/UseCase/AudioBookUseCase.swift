import Foundation

enum AudioBookError: Error {
    case emptyText
    case unsupportedDocument
}

@MainActor
protocol AudioBookUseCase {
    func speak(text: String) throws
    func pause()
    func resume()
    func stop()
}

@MainActor
final class ImpAudioBookUseCase: AudioBookUseCase {
    private let repository: any AudioBookRepository

    init(repository: any AudioBookRepository) {
        self.repository = repository
    }

    func speak(text: String) throws {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AudioBookError.emptyText }
        repository.speak(text)
    }

    func pause() { repository.pause() }
    func resume() { repository.resume() }
    func stop() { repository.stop() }
}
