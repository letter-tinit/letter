import Foundation
import Utility

@MainActor
public protocol BookAudioExportRepository: AnyObject {
    func export(
        book: Book,
        rate: Double,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL
    func cancel()
    func discardExport(at url: URL)
}
