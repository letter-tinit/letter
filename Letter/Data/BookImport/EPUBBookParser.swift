import Foundation
import UIKit
import ZIPFoundation

struct EPUBBookParser: BookDocumentParser {
    let format = BookFormat.epub

    func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument {
        let fileManager = FileManager.default
        let extractionURL = fileManager.temporaryDirectory
            .appendingPathComponent("LetterEPUB-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: extractionURL) }

        do {
            try fileManager.unzipItem(at: url, to: extractionURL)
        } catch {
            throw AudioBookError.malformedDocument
        }

        let packageURL = try locatePackage(in: extractionURL)
        let package = try parsePackage(at: packageURL)
        let baseURL = packageURL.deletingLastPathComponent()
        let navigationTitles = navigationTitles(package: package, baseURL: baseURL)
        let chapters = package.spineIDs.enumerated().compactMap { index, id -> BookChapter? in
            guard let item = package.manifest[id] else { return nil }
            let resourceURL = resolvedURL(for: item.href, relativeTo: baseURL)
            guard isContained(resourceURL, in: extractionURL),
                  let data = try? Data(contentsOf: resourceURL),
                  let content = htmlText(from: data),
                  !content.isEmpty else { return nil }
            let title = navigationTitles[resourceURL.standardizedFileURL.path]
                ?? firstHeading(in: data)
                ?? "Chapter \(index + 1)"
            return BookChapter(title: title, content: content, index: index)
        }

        guard !chapters.isEmpty else {
            let encryptionURL = extractionURL.appendingPathComponent("META-INF/encryption.xml")
            if fileManager.fileExists(atPath: encryptionURL.path) {
                throw AudioBookError.protectedDocument
            }
            throw AudioBookError.emptyBook
        }
        return ParsedBookDocument(title: package.title ?? fallbackTitle, chapters: chapters)
    }

    private func locatePackage(in extractionURL: URL) throws -> URL {
        let containerURL = extractionURL.appendingPathComponent("META-INF/container.xml")
        guard let parser = XMLParser(contentsOf: containerURL) else {
            throw AudioBookError.malformedDocument
        }
        let delegate = EPUBContainerXMLParser()
        parser.delegate = delegate
        guard parser.parse(), let packagePath = delegate.packagePath else {
            throw AudioBookError.malformedDocument
        }
        let packageURL = resolvedURL(for: packagePath, relativeTo: extractionURL)
        guard isContained(packageURL, in: extractionURL) else {
            throw AudioBookError.malformedDocument
        }
        return packageURL
    }

    private func parsePackage(at url: URL) throws -> EPUBPackageXMLParser {
        guard let parser = XMLParser(contentsOf: url) else { throw AudioBookError.malformedDocument }
        let delegate = EPUBPackageXMLParser()
        parser.delegate = delegate
        guard parser.parse(), !delegate.spineIDs.isEmpty else {
            throw AudioBookError.malformedDocument
        }
        return delegate
    }

    private func navigationTitles(
        package: EPUBPackageXMLParser,
        baseURL: URL
    ) -> [String: String] {
        guard let navigationItem = package.manifest.values.first(where: {
            $0.properties.contains("nav") || $0.mediaType == "application/x-dtbncx+xml"
        }) else { return [:] }
        let navigationURL = resolvedURL(for: navigationItem.href, relativeTo: baseURL)
        guard let parser = XMLParser(contentsOf: navigationURL) else { return [:] }
        let delegate = EPUBNavigationXMLParser()
        parser.delegate = delegate
        guard parser.parse() else { return [:] }
        let navigationBase = navigationURL.deletingLastPathComponent()
        return Dictionary(delegate.links.map {
            (resolvedURL(for: $0.href, relativeTo: navigationBase).standardizedFileURL.path, $0.title)
        }, uniquingKeysWith: { first, _ in first })
    }

    private func resolvedURL(for href: String, relativeTo baseURL: URL) -> URL {
        let path = href.split(separator: "#", maxSplits: 1).first.map(String.init) ?? href
        return baseURL.appendingPathComponent(path.removingPercentEncoding ?? path).standardizedFileURL
    }

    private func isContained(_ candidate: URL, in directory: URL) -> Bool {
        let directoryPath = directory.standardizedFileURL.path + "/"
        return candidate.standardizedFileURL.path.hasPrefix(directoryPath)
    }

    private func htmlText(from data: Data) -> String? {
        guard let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) else { return nil }
        return attributed.string
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstHeading(in data: Data) -> String? {
        guard let html = data.decodedBookText,
              let expression = try? NSRegularExpression(
                pattern: #"<h[1-6][^>]*>(.*?)</h[1-6]>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
              ),
              let match = expression.firstMatch(
                in: html,
                range: NSRange(html.startIndex..<html.endIndex, in: html)
              ),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return htmlText(from: Data(html[range].utf8))
    }
}
