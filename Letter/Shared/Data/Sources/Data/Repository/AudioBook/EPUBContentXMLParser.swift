import Foundation
import Domain
import Core
import Utility

public struct EPUBContentHeading {
    public let level: Int
    public let title: String
    public let offset: Int
}

public struct EPUBContentDocument {
    public let text: String
    public let anchorOffsets: [String: Int]
    public let headings: [EPUBContentHeading]
}

public final class EPUBContentXMLParser: NSObject, XMLParserDelegate {
    private struct ActiveHeading {
        let level: Int
        let offset: Int
        var parts: [String]
    }
    private static let blockElements: Set<String> = [
        "address", "article", "aside", "blockquote", "br", "div", "figcaption",
        "figure", "footer", "h1", "h2", "h3", "h4", "h5", "h6", "header",
        "hr", "li", "main", "nav", "ol", "p", "pre", "section", "table",
        "td", "th", "tr", "ul"
    ]
    private static let ignoredElements: Set<String> = ["head", "nav", "script", "style"]

    // NSMutableString grows the document incrementally without the repeated
    // whole-document copies caused by `String +=` or a final `[String].joined()`.
    private let text = NSMutableString()
    private var textLength = 0
    private var endsWithNewline = false
    private var anchors: [String: Int] = [:]
    private var headings: [EPUBContentHeading] = []
    private var ignoredDepth = 0
    private var activeHeading: ActiveHeading?

    public var document: EPUBContentDocument {
        EPUBContentDocument(text: text as String, anchorOffsets: anchors, headings: headings)
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = localName(elementName)
        if ignoredDepth > 0 {
            ignoredDepth += 1
            return
        }
        if Self.ignoredElements.contains(name) {
            ignoredDepth = 1
            return
        }
        if Self.blockElements.contains(name) { appendBoundary() }

        let offset = textLength
        for key in ["id", "xml:id", "name"] {
            if let identifier = attributeDict[key], !identifier.isEmpty {
                anchors[identifier] = anchors[identifier] ?? offset
            }
        }
        if let level = headingLevel(name) {
            activeHeading = ActiveHeading(level: level, offset: offset, parts: [])
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard ignoredDepth == 0 else { return }
        text.append(string)
        textLength += string.utf16.count
        endsWithNewline = string.last == "\n"
        activeHeading?.parts.append(string)
    }

    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let value = String(data: CDATABlock, encoding: .utf8) else { return }
        self.parser(parser, foundCharacters: value)
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if ignoredDepth > 0 {
            ignoredDepth -= 1
            return
        }
        let name = localName(elementName)
        if headingLevel(name) != nil, let heading = activeHeading {
            let title = normalized(heading.parts.joined())
            if !title.isEmpty {
                headings.append(
                    EPUBContentHeading(level: heading.level, title: title, offset: heading.offset)
                )
            }
            activeHeading = nil
        }
        if Self.blockElements.contains(name) { appendBoundary() }
    }

    private func appendBoundary() {
        guard textLength > 0, !endsWithNewline else { return }
        text.append("\n")
        textLength += 1
        endsWithNewline = true
    }

    private func headingLevel(_ name: String) -> Int? {
        guard name.count == 2, name.first == "h" else { return nil }
        return Int(String(name.last!)).flatMap { (1...6).contains($0) ? $0 : nil }
    }

    private func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init)?.lowercased() ?? name.lowercased()
    }

    private func normalized(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
