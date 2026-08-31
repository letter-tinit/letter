import SwiftUI
import UniformTypeIdentifiers
import Domain
import Core
import Utility
import Styleguide

public struct BackupDocument: FileDocument {
    public static let readableContentTypes: [UTType] = [.json]

    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
