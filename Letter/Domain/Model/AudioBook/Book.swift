import Foundation

enum BookFormat: String, Codable, Sendable {
    case text
    case rtf
    case pdf
}

struct Book: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var title: String
    var content: String
    let format: BookFormat
    let importedAt: Date
    var readingProgress: Double

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        format: BookFormat,
        importedAt: Date = .now,
        readingProgress: Double = 0
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.format = format
        self.importedAt = importedAt
        self.readingProgress = min(max(readingProgress, 0), 1)
    }
}
