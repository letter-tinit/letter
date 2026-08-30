import Foundation
import Testing
import ZIPFoundation
@testable import Letter

@MainActor
struct BookParserIntegrationTests {
    @Test
    func importsEPUBSpineAsChapters() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source")
        let epub = root.appendingPathComponent("sample.epub")
        try fileManager.createDirectory(
            at: source.appendingPathComponent("META-INF"),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: source.appendingPathComponent("OEBPS"),
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: root) }

        try write(
            """
            <?xml version="1.0"?>
            <container><rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles></container>
            """,
            to: source.appendingPathComponent("META-INF/container.xml")
        )
        try write(
            """
            <?xml version="1.0"?>
            <package xmlns:dc="http://purl.org/dc/elements/1.1/">
              <metadata><dc:title>Fixture Book</dc:title></metadata>
              <manifest>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="c1" href="one.xhtml" media-type="application/xhtml+xml"/>
                <item id="c2" href="two.xhtml" media-type="application/xhtml+xml"/>
              </manifest>
              <spine><itemref idref="c1"/><itemref idref="c2"/></spine>
            </package>
            """,
            to: source.appendingPathComponent("OEBPS/content.opf")
        )
        try write(
            "<html><body><nav><a href=\"one.xhtml\">Mở đầu</a><a href=\"two.xhtml\">Tiếp theo</a></nav></body></html>",
            to: source.appendingPathComponent("OEBPS/nav.xhtml")
        )
        try write(
            "<html><body><h1>Mở đầu</h1><p>Nội dung một.</p></body></html>",
            to: source.appendingPathComponent("OEBPS/one.xhtml")
        )
        try write(
            "<html><body><h1>Tiếp theo</h1><p>Nội dung hai.</p></body></html>",
            to: source.appendingPathComponent("OEBPS/two.xhtml")
        )
        try fileManager.zipItem(at: source, to: epub, shouldKeepParent: false)

        let parsed = try EPUBBookParser().parse(url: epub, fallbackTitle: "Fallback")

        #expect(parsed.title == "Fixture Book")
        #expect(parsed.chapters.count == 2)
        #expect(parsed.chapters[0].title == "Mở đầu")
        #expect(parsed.chapters[1].content.contains("Nội dung hai"))
    }

    @Test
    func importsUnencryptedPalmDOCCompressedAZW3() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).azw3")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let html = "<html><body>Chương 1: Bắt đầu\nNội dung AZW3.</body></html>"
        try makeAZW3(text: html, encryption: 0).write(to: fileURL)

        let parsed = try AZW3BookParser().parse(url: fileURL, fallbackTitle: "Kindle")

        #expect(parsed.chapters.count == 1)
        #expect(parsed.chapters[0].content.contains("Nội dung AZW3"))
    }

    @Test
    func rejectsProtectedAZW3() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).azw3")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try makeAZW3(text: "Protected", encryption: 1).write(to: fileURL)

        #expect(throws: AudioBookError.protectedDocument) {
            try AZW3BookParser().parse(url: fileURL, fallbackTitle: "Protected")
        }
    }

    private func write(_ string: String, to url: URL) throws {
        try Data(string.utf8).write(to: url)
    }

    private func makeAZW3(text: String, encryption: UInt16) -> Data {
        let textData = Data(text.utf8)
        let recordZeroOffset = 94
        let textRecordOffset = 126
        var file = Data(repeating: 0, count: recordZeroOffset)
        file.setBigEndianUInt16(2, at: 76)
        file.setBigEndianUInt32(UInt32(recordZeroOffset), at: 78)
        file.setBigEndianUInt32(UInt32(textRecordOffset), at: 86)

        var header = Data(repeating: 0, count: 32)
        header.setBigEndianUInt16(1, at: 0)
        header.setBigEndianUInt32(UInt32(textData.count), at: 4)
        header.setBigEndianUInt16(1, at: 8)
        header.setBigEndianUInt16(4_096, at: 10)
        header.setBigEndianUInt16(encryption, at: 12)
        header.replaceSubrange(16..<20, with: Data("MOBI".utf8))
        header.setBigEndianUInt32(65_001, at: 28)
        file.append(header)
        file.append(textData)
        return file
    }
}

private extension Data {
    mutating func setBigEndianUInt16(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8((value >> 8) & 0xFF)
        self[offset + 1] = UInt8(value & 0xFF)
    }

    mutating func setBigEndianUInt32(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8((value >> 24) & 0xFF)
        self[offset + 1] = UInt8((value >> 16) & 0xFF)
        self[offset + 2] = UInt8((value >> 8) & 0xFF)
        self[offset + 3] = UInt8(value & 0xFF)
    }
}
