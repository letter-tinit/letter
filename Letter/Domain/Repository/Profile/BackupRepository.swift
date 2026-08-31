import Foundation

@MainActor
protocol BackupRepository: AnyObject {
    func exportBackup() throws -> BackupFile
    func inspectBackup(at url: URL) throws -> BackupImport
    func restoreBackup(_ data: Data) throws
    func clearAllData() throws
}
