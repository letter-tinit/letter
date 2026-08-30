import Foundation
import Testing
import ZIPFoundation
@testable import Letter

@MainActor
struct BookParserIntegrationTests {
    @Test
    func preservesOneGroupLevelFromEPUB3Navigation() throws {
        let data = Data(
            """
            <html xmlns:epub="http://www.idpf.org/2007/ops"><body>
              <nav epub:type="toc"><ol><li><span>Phần I</span><ol>
                <li><a href="one.xhtml">Mục 1</a></li>
                <li><a href="two.xhtml">Mục 2</a></li>
              </ol></li></ol></nav>
            </body></html>
            """.utf8
        )
        let parser = XMLParser(data: data)
        let delegate = EPUBNavigationXMLParser()
        parser.delegate = delegate

        #expect(parser.parse())
        #expect(delegate.links.map(\.groupTitle) == ["Phần I", "Phần I"])
    }

    @Test
    func mergesGroupLabelsAndUnnamedSpineContinuationsIntoPlayableContent() throws {
        let package = """
        <package><metadata><title>Grouped</title></metadata><manifest>
          <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
          <item id="copyright" href="index_split_001.xhtml" media-type="application/xhtml+xml"/>
          <item id="root" href="root.xhtml" media-type="application/xhtml+xml"/>
          <item id="label" href="label.xhtml" media-type="application/xhtml+xml"/>
          <item id="body" href="body.xhtml" media-type="application/xhtml+xml"/>
          <item id="tail" href="untitled-resource.xhtml" media-type="application/xhtml+xml"/>
        </manifest><spine><itemref idref="copyright"/><itemref idref="root"/><itemref idref="label"/>
          <itemref idref="body"/><itemref idref="tail"/></spine></package>
        """
        let body = String(repeating: "Nội dung chính. ", count: 60)
        let epub = try makeEPUB(
            package: package,
            files: [
                "nav.xhtml": """
                <html xmlns:epub="http://www.idpf.org/2007/ops"><body><nav epub:type="toc"><ol>
                  <li><a href="root.xhtml">Phần I</a><ol>
                    <li><a href="label.xhtml">Tiêu đề nhỏ</a></li>
                    <li><a href="body.xhtml">Nội dung</a></li>
                  </ol></li>
                </ol></nav></body></html>
                """,
                "index_split_001.xhtml": "<html><body><p>Copyright © Example Publisher.</p></body></html>",
                "root.xhtml": "<html><body><h1>Phần I</h1></body></html>",
                "label.xhtml": "<html><body><h2>Tiêu đề nhỏ</h2></body></html>",
                "body.xhtml": "<html><body><h2>Nội dung</h2><p>\(body)</p></body></html>",
                "untitled-resource.xhtml": "<html><body><p>Đoạn tiếp nối.</p></body></html>"
            ]
        )
        defer { try? FileManager.default.removeItem(at: epub.deletingLastPathComponent()) }

        let parsed = try EPUBBookParser().parse(url: epub, fallbackTitle: "Fallback")

        #expect(parsed.chapters.count == 2)
        #expect(parsed.chapters[0].role == .copyright)
        #expect(parsed.chapters[1].groupTitle == "Phần I")
        #expect(parsed.chapters[1].title == "Tiêu đề nhỏ — Nội dung")
        #expect(parsed.chapters[1].content.contains("Đoạn tiếp nối"))
    }

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
    func splitsSingleDocumentUsingEPUB3TOCFragments() throws {
        let epub = try makeEPUB(
            package: epub3Package,
            files: [
                "nav.xhtml": """
                <html xmlns:epub="http://www.idpf.org/2007/ops"><body>
                  <nav epub:type="toc"><ol><li><a href="book.xhtml#one">Phần Một</a><ol>
                    <li><a href="book.xhtml#one">Chương Một</a></li>
                    <li><a href="book.xhtml#two">Chương Hai</a></li>
                  </ol></li></ol></nav>
                  <nav epub:type="page-list"><a href="book.xhtml#page-2">Trang 2</a></nav>
                </body></html>
                """,
                "book.xhtml": """
                <html><body>
                  <h1 id="one">Tiêu đề một</h1><p>Nội dung chương một.</p>
                  <span id="page-2"/>
                  <h1 id="two">Tiêu đề hai</h1><p>Nội dung chương hai.</p>
                </body></html>
                """
            ]
        )
        defer { try? FileManager.default.removeItem(at: epub.deletingLastPathComponent()) }

        let parsed = try EPUBBookParser().parse(url: epub, fallbackTitle: "Fallback")

        #expect(parsed.chapters.count == 2)
        #expect(parsed.chapters.map(\.title) == ["Chương Một", "Chương Hai"])
        #expect(parsed.chapters.map(\.groupTitle) == ["Phần Một", "Phần Một"])
        #expect(parsed.chapters[0].content.contains("Nội dung chương một"))
        #expect(!parsed.chapters[0].content.contains("Nội dung chương hai"))
    }

    @Test
    func supportsNestedEPUB2NCXNavigationOrder() throws {
        let package = """
        <package xmlns:dc="http://purl.org/dc/elements/1.1/">
          <metadata><dc:title>EPUB 2</dc:title></metadata>
          <manifest>
            <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
            <item id="book" href="book.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine toc="ncx"><itemref idref="book"/></spine>
        </package>
        """
        let ncx = """
        <ncx><navMap>
          <navPoint><navLabel><text>Phần Một</text></navLabel><content src="book.xhtml#one"/>
            <navPoint><navLabel><text>Phần Hai</text></navLabel><content src="book.xhtml#two"/></navPoint>
          </navPoint>
        </navMap></ncx>
        """
        let epub = try makeEPUB(
            package: package,
            files: [
                "toc.ncx": ncx,
                "book.xhtml": "<html><body><h2 id=\"one\">Một</h2><p>A</p><h2 id=\"two\">Hai</h2><p>B</p></body></html>"
            ]
        )
        defer { try? FileManager.default.removeItem(at: epub.deletingLastPathComponent()) }

        let parsed = try EPUBBookParser().parse(url: epub, fallbackTitle: "Fallback")

        #expect(parsed.chapters.map(\.title) == ["Phần Hai"])
        #expect(parsed.chapters[0].groupTitle == "Phần Một")
        #expect(parsed.chapters[0].content.contains("A"))
        #expect(parsed.chapters[0].content.contains("B"))
    }

    @Test
    func fallsBackToRepeatedHeadingLevelWithoutNavigation() throws {
        let package = """
        <package xmlns:dc="http://purl.org/dc/elements/1.1/">
          <metadata><dc:title>Không TOC</dc:title></metadata>
          <manifest><item id="book" href="book.xhtml" media-type="application/xhtml+xml"/></manifest>
          <spine><itemref idref="book"/></spine>
        </package>
        """
        let epub = try makeEPUB(
            package: package,
            files: [
                "book.xhtml": "<html><body><h2>Mở đầu</h2><p>A</p><h2>Kết thúc</h2><p>B</p></body></html>"
            ]
        )
        defer { try? FileManager.default.removeItem(at: epub.deletingLastPathComponent()) }

        let parsed = try EPUBBookParser().parse(url: epub, fallbackTitle: "Fallback")

        #expect(parsed.chapters.map(\.title) == ["Mở đầu", "Kết thúc"])
    }

    private var epub3Package: String {
        """
        <package xmlns:dc="http://purl.org/dc/elements/1.1/">
          <metadata><dc:title>EPUB 3</dc:title></metadata>
          <manifest>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="book" href="book.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="book"/></spine>
        </package>
        """
    }

    private func makeEPUB(package: String, files: [String: String]) throws -> URL {
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
        try write(
            "<container><rootfiles><rootfile full-path=\"OEBPS/content.opf\"/></rootfiles></container>",
            to: source.appendingPathComponent("META-INF/container.xml")
        )
        try write(package, to: source.appendingPathComponent("OEBPS/content.opf"))
        for (path, content) in files {
            try write(content, to: source.appendingPathComponent("OEBPS/\(path)"))
        }
        try fileManager.zipItem(at: source, to: epub, shouldKeepParent: false)
        return epub
    }

    private func write(_ string: String, to url: URL) throws {
        try Data(string.utf8).write(to: url)
    }
}
