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
    private(set) var coverImageID: String?
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
        } else if name == "meta", attributeDict["name"]?.lowercased() == "cover" {
            coverImageID = attributeDict["content"]
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
    struct Link {
        let href: String
        let title: String
        let groupTitle: String?
    }

    private struct OrderedLink {
        let order: Int
        let href: String
        let title: String
        let groupTitle: String?
    }

    private struct NCXPoint {
        let order: Int
        var href: String?
        var title = ""
        var capturesTitle = false
        let groupTitle: String?
    }

    private var allHTMLLinks: [OrderedLink] = []
    private var tocHTMLLinks: [OrderedLink] = []
    private var ncxLinks: [OrderedLink] = []
    private var activeAnchor: (order: Int, href: String, text: String, isTOC: Bool, group: String?)?
    private var ncxStack: [NCXPoint] = []
    private var elementDepth = 0
    private var tocNavigationDepth: Int?
    private var nextOrder = 0
    private var listDepth = 0
    private var rootHTMLTitle: String?
    private var groupLabelBuffer: String?

    var links: [Link] {
        let candidates = !ncxLinks.isEmpty
            ? ncxLinks
            : (!tocHTMLLinks.isEmpty ? tocHTMLLinks : allHTMLLinks)
        return candidates.sorted { $0.order < $1.order }.map {
            Link(href: $0.href, title: $0.title, groupTitle: $0.groupTitle)
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = elementName.lowercased()
        elementDepth += 1
        if name.hasSuffix("nav"), isTOCNavigation(attributeDict) {
            tocNavigationDepth = elementDepth
        } else if name.hasSuffix("ol"), tocNavigationDepth != nil {
            listDepth += 1
        } else if name.hasSuffix("a"), let href = attributeDict["href"] {
            activeAnchor = (takeOrder(), href, "", tocNavigationDepth != nil, listDepth > 1 ? rootHTMLTitle : nil)
        } else if name.hasSuffix("span"), tocNavigationDepth != nil, listDepth == 1 {
            groupLabelBuffer = ""
        } else if name.hasSuffix("navpoint") {
            ncxStack.append(
                NCXPoint(
                    order: takeOrder(),
                    groupTitle: ncxStack.first.map { normalized($0.title) }
                )
            )
        } else if name.hasSuffix("content"), let source = attributeDict["src"], !ncxStack.isEmpty {
            ncxStack[ncxStack.count - 1].href = source
        } else if name.hasSuffix("text"), !ncxStack.isEmpty {
            ncxStack[ncxStack.count - 1].capturesTitle = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeAnchor != nil { activeAnchor?.text += string }
        if groupLabelBuffer != nil { groupLabelBuffer? += string }
        if ncxStack.last?.capturesTitle == true {
            ncxStack[ncxStack.count - 1].title += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.lowercased()
        if name.hasSuffix("a") {
            appendAnchor()
        } else if name.hasSuffix("span"), let label = groupLabelBuffer {
            let title = normalized(label)
            if !title.isEmpty { rootHTMLTitle = title }
            groupLabelBuffer = nil
        } else if name.hasSuffix("ol"), tocNavigationDepth != nil {
            listDepth = max(listDepth - 1, 0)
        } else if name.hasSuffix("text"), !ncxStack.isEmpty {
            ncxStack[ncxStack.count - 1].capturesTitle = false
        } else if name.hasSuffix("navpoint"), let point = ncxStack.popLast() {
            let title = normalized(point.title)
            if let href = point.href, !title.isEmpty {
                ncxLinks.append(
                    OrderedLink(
                        order: point.order,
                        href: href,
                        title: title,
                        groupTitle: point.groupTitle
                    )
                )
            }
        }
        if tocNavigationDepth == elementDepth, name.hasSuffix("nav") {
            tocNavigationDepth = nil
        }
        elementDepth -= 1
    }

    private func appendAnchor() {
        guard let anchor = activeAnchor else { return }
        let title = normalized(anchor.text)
        if !title.isEmpty {
            if anchor.isTOC, listDepth == 1 { rootHTMLTitle = title }
            let link = OrderedLink(
                order: anchor.order,
                href: anchor.href,
                title: title,
                groupTitle: anchor.group
            )
            allHTMLLinks.append(link)
            if anchor.isTOC { tocHTMLLinks.append(link) }
        }
        activeAnchor = nil
    }

    private func isTOCNavigation(_ attributes: [String: String]) -> Bool {
        let type = attributes["epub:type"] ?? attributes["type"] ?? ""
        return type.split(separator: " ").contains { $0.lowercased() == "toc" }
    }

    private func takeOrder() -> Int {
        defer { nextOrder += 1 }
        return nextOrder
    }

    private func normalized(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
