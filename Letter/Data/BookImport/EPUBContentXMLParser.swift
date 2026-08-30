import Foundation

struct EPUBContentHeading {
    let level: Int
    let title: String
    let offset: Int
}

struct EPUBContentDocument {
    let text: String
    let anchorOffsets: [String: Int]
    let headings: [EPUBContentHeading]
}

final class EPUBContentXMLParser: NSObject, XMLParserDelegate {
    private static let blockElements: Set<String> = [
        "address", "article", "aside", "blockquote", "br", "div", "figcaption",
        "figure", "footer", "h1", "h2", "h3", "h4", "h5", "h6", "header",
        "hr", "li", "main", "nav", "ol", "p", "pre", "section", "table",
        "td", "th", "tr", "ul"
    ]
    private static let ignoredElements: Set<String> = ["head", "nav", "script", "style"]

    private var text = ""
    private var anchors: [String: Int] = [:]
    private var headings: [EPUBContentHeading] = []
    private var ignoredDepth = 0
    private var activeHeading: (level: Int, offset: Int, text: String)?

    var document: EPUBContentDocument {
        EPUBContentDocument(text: text, anchorOffsets: anchors, headings: headings)
    }

    func parser(
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

        let offset = text.utf16.count
        for key in ["id", "xml:id", "name"] {
            if let identifier = attributeDict[key], !identifier.isEmpty {
                anchors[identifier] = anchors[identifier] ?? offset
            }
        }
        if let level = headingLevel(name) {
            activeHeading = (level, offset, "")
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard ignoredDepth == 0 else { return }
        text += string
        if activeHeading != nil { activeHeading?.text += string }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let value = String(data: CDATABlock, encoding: .utf8) else { return }
        self.parser(parser, foundCharacters: value)
    }

    func parser(
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
            let title = normalized(heading.text)
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
        guard !text.isEmpty, !text.hasSuffix("\n") else { return }
        text.append("\n")
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
