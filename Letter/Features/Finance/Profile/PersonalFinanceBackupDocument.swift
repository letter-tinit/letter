//
//  PersonalFinanceBackupDocument.swift
//  Personal Finance
//
//  Created by Codex on 22/7/26.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PersonalFinanceBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var backup: PersonalFinanceBackup

    init(backup: PersonalFinanceBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        backup = try decoder.decode(PersonalFinanceBackup.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        return FileWrapper(regularFileWithContents: data)
    }
}
