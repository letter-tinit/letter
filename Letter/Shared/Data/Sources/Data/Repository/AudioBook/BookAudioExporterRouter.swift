import Foundation
import Domain

@MainActor
public final class BookAudioExporterRouter: BookAudioExportRepository {
    private let settings: any SpeechProviderSettingsRepository
    private let appleExporter: any BookAudioExportRepository
    private let googleExporter: any BookAudioExportRepository
    private var activeExporter: (any BookAudioExportRepository)?

    public init(
        settings: any SpeechProviderSettingsRepository,
        appleExporter: any BookAudioExportRepository,
        googleExporter: any BookAudioExportRepository
    ) {
        self.settings = settings
        self.appleExporter = appleExporter
        self.googleExporter = googleExporter
    }

    public func export(
        book: Book,
        rate: Double,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        let exporter = settings.loadProvider() == .googleCloud ? googleExporter : appleExporter
        activeExporter = exporter
        defer { activeExporter = nil }
        return try await exporter.export(book: book, rate: rate, onProgress: onProgress)
    }

    public func cancel() {
        activeExporter?.cancel()
    }

    public func discardExport(at url: URL) {
        appleExporter.discardExport(at: url)
        googleExporter.discardExport(at: url)
    }
}
