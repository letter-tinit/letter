import Foundation

struct EPUBManifestItem {
    let id: String
    let href: String
    let mediaType: String
    let properties: Set<String>
}

final class EPUBContainerXMLParser: NSObject, XMLParserDelegate {
    private(set) var packagePath: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.lowercased().hasSuffix("rootfile") else { return }
        packagePath = attributeDict["full-path"]
    }
}

final class EPUBPackageXMLParser: NSObject, XMLParserDelegate {
    private(set) var title: String?
    private(set) var manifest: [String: EPUBManifestItem] = [:]
    private(set) var spineIDs: [String] = []
    private var capturesTitle = false
    private var titleBuffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = elementName.lowercased()
        if name == "dc:title" || name.hasSuffix(":title") {
            capturesTitle = true
            titleBuffer = ""
        } else if name.hasSuffix("item"),
                  let id = attributeDict["id"],
                  let href = attributeDict["href"] {
            manifest[id] = EPUBManifestItem(
                id: id,
                href: href,
                mediaType: attributeDict["media-type"] ?? "",
                properties: Set((attributeDict["properties"] ?? "").split(separator: " ").map(String.init))
            )
        } else if name.hasSuffix("itemref"), let id = attributeDict["idref"] {
            spineIDs.append(id)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturesTitle { titleBuffer += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.lowercased()
        guard name == "dc:title" || name.hasSuffix(":title") else { return }
        capturesTitle = false
        let value = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if title == nil, !value.isEmpty { title = value }
    }
}

final class EPUBNavigationXMLParser: NSObject, XMLParserDelegate {
    private(set) var links: [(href: String, title: String)] = []
    private var activeHref: String?
    private var textBuffer = ""
    private var capturesNCXText = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = elementName.lowercased()
        if name.hasSuffix("a"), let href = attributeDict["href"] {
            activeHref = href
            textBuffer = ""
        } else if name.hasSuffix("navpoint") {
            activeHref = nil
            textBuffer = ""
        } else if name.hasSuffix("content"), let source = attributeDict["src"] {
            activeHref = source
        } else if name.hasSuffix("text"), activeHref != nil {
            capturesNCXText = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeHref != nil { textBuffer += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.lowercased()
        if name.hasSuffix("a") {
            appendActiveLink()
        } else if name.hasSuffix("text") {
            capturesNCXText = false
        } else if name.hasSuffix("navpoint"), !capturesNCXText {
            appendActiveLink()
        }
    }

    private func appendActiveLink() {
        guard let activeHref else { return }
        let title = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { links.append((activeHref, title)) }
        self.activeHref = nil
        textBuffer = ""
    }
}
