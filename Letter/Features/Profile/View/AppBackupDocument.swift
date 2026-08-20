import SwiftUI
import UniformTypeIdentifiers

struct AppBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let backup: AppBackup

    init(backup: AppBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        backup = try AppBackupStore.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try AppBackupStore.encode(backup))
    }
}
