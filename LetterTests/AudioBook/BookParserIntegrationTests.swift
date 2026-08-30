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

    private func write(_ string: String, to url: URL) throws {
        try Data(string.utf8).write(to: url)
    }
}
