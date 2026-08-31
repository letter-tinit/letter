import Foundation
import UIKit
import ZIPFoundation
import Domain
import Core
import Utility

public struct EPUBBookParser: BookDocumentParser {
    private static let largeBookTotalByteThreshold = 2_000_000
    private static let largeBookDocumentByteThreshold = 500_000
    private static let largeBookSpineCountThreshold = 500
    private struct NavigationReference {
        let path: String
        let fragment: String?
        let title: String
        let groupTitle: String?
    }

    private struct LoadedDocument {
        let content: EPUBContentDocument
        let fallbackTitle: String
    }

    public let format = BookFormat.epub
    private let segmenter = BookChapterSegmenter()

    public func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument {
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
        let spineItems = package.spineIDs.compactMap { package.manifest[$0] }
        let spineSizes = spineItems.map { item in
            let resourceURL = resolvedURL(for: item.href, relativeTo: baseURL)
            return (try? resourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        let totalSpineBytes = spineSizes.reduce(0, +)
        let maximumDocumentBytes = spineSizes.max() ?? 0
        let isLargeBook = totalSpineBytes >= Self.largeBookTotalByteThreshold
            || maximumDocumentBytes >= Self.largeBookDocumentByteThreshold
            || spineItems.count >= Self.largeBookSpineCountThreshold
        if isLargeBook {
            let compatibilityImport = {
                try parseWithF311Compatibility(
                    package: package,
                    baseURL: baseURL,
                    extractionURL: extractionURL,
                    fallbackTitle: fallbackTitle,
                    totalSpineBytes: totalSpineBytes,
                    maximumDocumentBytes: maximumDocumentBytes
                )
            }
            if Thread.isMainThread { return try compatibilityImport() }
            return try DispatchQueue.main.sync(execute: compatibilityImport)
        }

        logDebug(
            "[Letter][EPUB] profile=standard | spineBytes=\(totalSpineBytes) | maxDocumentBytes=\(maximumDocumentBytes) | spineItems=\(spineItems.count)"
        )
        let references = navigationReferences(package: package, baseURL: baseURL)
        let chapters = chapters(
            package: package,
            baseURL: baseURL,
            extractionURL: extractionURL,
            navigation: references
        )

        guard !chapters.isEmpty else {
            let encryptionURL = extractionURL.appendingPathComponent("META-INF/encryption.xml")
            if fileManager.fileExists(atPath: encryptionURL.path) {
                throw AudioBookError.protectedDocument
            }
            throw AudioBookError.emptyBook
        }
        let normalizedChapters = normalizedHierarchy(from: chapters)
        let indexedChapters = normalizedChapters.enumerated().map {
            BookChapter(
                title: $0.element.title,
                content: $0.element.content,
                index: $0.offset,
                groupTitle: $0.element.groupTitle,
                role: $0.element.role
            )
        }
        logChapterSummary(bookTitle: package.title ?? fallbackTitle, chapters: indexedChapters)
        return ParsedBookDocument(
            title: package.title ?? fallbackTitle,
            chapters: indexedChapters,
            coverData: coverData(package: package, baseURL: baseURL, extractionURL: extractionURL),
            languageCode: package.languageCode
        )
    }

    private func parseWithF311Compatibility(
        package: EPUBPackageXMLParser,
        baseURL: URL,
        extractionURL: URL,
        fallbackTitle: String,
        totalSpineBytes: Int,
        maximumDocumentBytes: Int
    ) throws -> ParsedBookDocument {
        logDebug(
            "[Letter][EPUB] profile=f311-compatibility | spineBytes=\(totalSpineBytes) | maxDocumentBytes=\(maximumDocumentBytes) | spineItems=\(package.spineIDs.count)"
        )
        let titles = compatibilityNavigationTitles(package: package, baseURL: baseURL)
        let chapters = package.spineIDs.enumerated().compactMap { index, id -> BookChapter? in
            guard let item = package.manifest[id] else { return nil }
            let resourceURL = resolvedURL(for: item.href, relativeTo: baseURL)
            guard isContained(resourceURL, in: extractionURL),
                  let data = try? Data(contentsOf: resourceURL),
                  let content = compatibilityHTMLText(from: data),
                  !content.isEmpty else { return nil }
            let title = titles[resourceURL.standardizedFileURL.path]
                ?? compatibilityFirstHeading(in: data)
                ?? "Chapter \(index + 1)"
            return BookChapter(
                title: title,
                content: content,
                index: index
            )
        }

        guard !chapters.isEmpty else {
            let encryptionURL = extractionURL.appendingPathComponent("META-INF/encryption.xml")
            if FileManager.default.fileExists(atPath: encryptionURL.path) {
                throw AudioBookError.protectedDocument
            }
            throw AudioBookError.emptyBook
        }
        // Keep this return equivalent to f311c7cb: no hierarchy normalization
        // and no cover decoding after all text has already been materialized.
        return ParsedBookDocument(
            title: package.title ?? fallbackTitle,
            chapters: chapters,
            languageCode: package.languageCode
        )
    }

    private func compatibilityNavigationTitles(
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

    private func compatibilityHTMLText(from data: Data) -> String? {
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

    private func compatibilityFirstHeading(in data: Data) -> String? {
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
        return compatibilityHTMLText(from: Data(html[range].utf8))
    }

    private func coverData(
        package: EPUBPackageXMLParser,
        baseURL: URL,
        extractionURL: URL
    ) -> Data? {
        let item = package.coverImageID.flatMap { package.manifest[$0] }
            ?? package.manifest.values.first(where: { $0.properties.contains("cover-image") })
            ?? package.manifest.values.first(where: { $0.mediaType.hasPrefix("image/") })
        guard let item else { return nil }
        let url = resolvedURL(for: item.href, relativeTo: baseURL)
        guard isContained(url, in: extractionURL) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let image = UIImage(data: data) else { return data }
        return image.preparingThumbnail(of: CGSize(width: 320, height: 480))?
            .jpegData(compressionQuality: 0.8) ?? data
    }

    private func normalizedHierarchy(from chapters: [BookChapter]) -> [BookChapter] {
        let withoutGroupHeaders = removingStandaloneGroupHeaders(from: chapters)
        let withPlayableSections = mergingShortNavigationLabels(in: withoutGroupHeaders)
        return replacingGeneratedTitles(in: withPlayableSections)
    }

    private func removingStandaloneGroupHeaders(from chapters: [BookChapter]) -> [BookChapter] {
        var result: [BookChapter] = []
        for chapter in chapters {
            if let groupTitle = chapter.groupTitle,
               let header = result.last,
               header.groupTitle == nil,
               normalized(header.title).localizedCaseInsensitiveCompare(normalized(groupTitle)) == .orderedSame {
                result.removeLast()
                let content = normalized(header.content + "\n\n" + chapter.content)
                result.append(
                    BookChapter(
                        title: chapter.title,
                        content: content,
                        index: chapter.index,
                        groupTitle: groupTitle
                    )
                )
            } else {
                result.append(chapter)
            }
        }
        return result
    }

    private func mergingShortNavigationLabels(in chapters: [BookChapter]) -> [BookChapter] {
        var result: [BookChapter] = []
        var index = 0
        while index < chapters.count {
            let chapter = chapters[index]
            if isNavigationLabelOnly(chapter), let groupTitle = chapter.groupTitle {
                var targetIndex = index + 1
                while chapters.indices.contains(targetIndex),
                      chapters[targetIndex].groupTitle == groupTitle,
                      isNavigationLabelOnly(chapters[targetIndex]) {
                    targetIndex += 1
                }
                guard chapters.indices.contains(targetIndex),
                      chapters[targetIndex].groupTitle == groupTitle else {
                    result.append(chapter)
                    index += 1
                    continue
                }
                let labels = chapters[index..<targetIndex]
                let target = chapters[targetIndex]
                let title = labels.dropFirst().reduce(labels.first!.title) {
                    combinedTitle($0, $1.title)
                }
                let content = labels.map(\.content).joined(separator: "\n\n")
                result.append(
                    BookChapter(
                        title: combinedTitle(title, target.title),
                        content: normalized(content + "\n\n" + target.content),
                        index: chapter.index,
                        groupTitle: groupTitle
                    )
                )
                index = targetIndex + 1
            } else {
                result.append(chapter)
                index += 1
            }
        }
        return result
    }

    private func isNavigationLabelOnly(_ chapter: BookChapter) -> Bool {
        guard chapter.content.count <= 500 else { return false }
        let labels = normalized([chapter.groupTitle, chapter.title].compactMap { $0 }.joined(separator: " "))
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let lines = chapter.content.components(separatedBy: .newlines)
            .map(normalized)
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }
        return lines.allSatisfy { line in
            let comparable = line.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            return labels.contains(comparable)
        }
    }

    private func isGeneratedFileTitle(_ title: String) -> Bool {
        title.range(of: #"^index_split_\d+$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func replacingGeneratedTitles(in chapters: [BookChapter]) -> [BookChapter] {
        chapters.map { chapter in
            guard isGeneratedFileTitle(chapter.title) else { return chapter }
            let semantic = semanticMetadata(for: chapter.content)
            return BookChapter(
                title: semantic.title,
                content: chapter.content,
                index: chapter.index,
                groupTitle: chapter.groupTitle,
                role: semantic.role
            )
        }
    }

    private func semanticMetadata(for content: String) -> (title: String, role: BookSectionRole?) {
        let value = normalized(content)
        let lowercase = value.lowercased()
        let firstLine = value.components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if lowercase.contains("chịu trách nhiệm xuất bản") ||
            (value.count < 1_500 && lowercase.contains("nhà xuất bản")) {
            return (firstLine ?? "", .publicationInfo)
        }
        if value.count < 1_500 &&
            (lowercase.contains("copyright") || lowercase.contains("bản quyền")) {
            return (firstLine ?? "", .copyright)
        }
        if let firstLine, firstLine.count <= 120 { return (firstLine, nil) }
        return ("", .supplementary)
    }

    private func combinedTitle(_ first: String, _ second: String) -> String {
        let firstTitle = normalized(first)
        let secondTitle = normalized(second)
        guard firstTitle.localizedCaseInsensitiveCompare(secondTitle) != .orderedSame else {
            return secondTitle
        }
        return "\(firstTitle) — \(secondTitle)"
    }

    private func logChapterSummary(bookTitle: String, chapters: [BookChapter]) {
        logDebug("[Letter][EPUB] book=\(bookTitle) | chapters=\(chapters.count)")
        for chapter in chapters {
            logDebug(
                "[Letter][EPUB] chapter=\(chapter.index + 1) | group=\(chapter.groupTitle ?? "-") | role=\(chapter.role?.rawValue ?? "-") | title=\(chapter.title) | characters=\(chapter.content.count)"
            )
        }
    }

    private func chapters(
        package: EPUBPackageXMLParser,
        baseURL: URL,
        extractionURL: URL,
        navigation: [NavigationReference]
    ) -> [BookChapter] {
        let spineItems: [EPUBManifestItem] = package.spineIDs.compactMap { id in
            package.manifest[id]
        }
        var result: [BookChapter] = []
        for item in spineItems {
            guard !item.properties.contains("nav") else { continue }
            let resourceURL = resolvedURL(for: item.href, relativeTo: baseURL)
            guard isContained(resourceURL, in: extractionURL),
                  let document = loadDocument(at: resourceURL) else { continue }
            let links = navigation.filter { $0.path == resourceURL.standardizedFileURL.path }
            let parsed = chapters(from: document, navigation: links)
            if links.isEmpty, document.content.headings.isEmpty, parsed.count == 1,
               let previous = result.last, let groupTitle = previous.groupTitle {
                result.removeLast()
                result.append(
                    BookChapter(
                        title: previous.title,
                        content: normalized(previous.content + "\n\n" + parsed[0].content),
                        index: previous.index,
                        groupTitle: groupTitle
                    )
                )
            } else {
                result.append(contentsOf: parsed)
            }
        }
        return result
    }

    private func chapters(
        from document: LoadedDocument,
        navigation: [NavigationReference]
    ) -> [BookChapter] {
        let navigationChapters = chaptersFromNavigation(document, references: navigation)
        if !navigationChapters.isEmpty { return navigationChapters }

        let headingChapters = chaptersFromHeadings(document)
        if !headingChapters.isEmpty { return headingChapters }

        return segmenter.chapters(
            from: normalized(document.content.text),
            fallbackTitle: document.fallbackTitle
        )
    }

    private func chaptersFromNavigation(
        _ document: LoadedDocument,
        references: [NavigationReference]
    ) -> [BookChapter] {
        var markers: [(offset: Int, title: String, groupTitle: String?)] = []
        for reference in references {
            let offset: Int
            if let fragment = reference.fragment {
                guard let anchorOffset = document.content.anchorOffsets[fragment] else { continue }
                offset = anchorOffset
            } else {
                offset = 0
            }
            if let existingIndex = markers.firstIndex(where: { $0.offset == offset }) {
                if markers[existingIndex].groupTitle == nil, reference.groupTitle != nil {
                    markers[existingIndex] = (offset, reference.title, reference.groupTitle)
                }
            } else {
                markers.append((offset, reference.title, reference.groupTitle))
            }
        }
        markers.sort { $0.offset < $1.offset }
        return chapters(
            text: document.content.text,
            markers: markers,
            prefixTitle: document.fallbackTitle
        )
    }

    private func chaptersFromHeadings(_ document: LoadedDocument) -> [BookChapter] {
        let headings = document.content.headings
        let selectedLevel = (1...6).first { level in
            headings.filter { $0.level == level }.count >= 2
        }
        guard let selectedLevel else { return [] }
        let markers: [(offset: Int, title: String, groupTitle: String?)] = headings
            .filter { $0.level == selectedLevel }.map {
            (offset: $0.offset, title: $0.title, groupTitle: nil)
        }
        return chapters(
            text: document.content.text,
            markers: markers,
            prefixTitle: document.fallbackTitle
        )
    }

    private func chapters(
        text: String,
        markers: [(offset: Int, title: String, groupTitle: String?)],
        prefixTitle: String
    ) -> [BookChapter] {
        guard !markers.isEmpty else { return [] }
        let source = text as NSString
        var result: [BookChapter] = []
        let firstOffset = min(max(markers[0].offset, 0), source.length)
        appendChapter(title: prefixTitle, text: source.substring(to: firstOffset), to: &result)
        for (index, marker) in markers.enumerated() {
            let start = min(max(marker.offset, 0), source.length)
            let proposedEnd = index + 1 < markers.count ? markers[index + 1].offset : source.length
            let end = min(max(proposedEnd, start), source.length)
            appendChapter(
                title: marker.title,
                text: source.substring(with: NSRange(location: start, length: end - start)),
                groupTitle: marker.groupTitle,
                to: &result
            )
        }
        return result
    }

    private func appendChapter(
        title: String,
        text: String,
        groupTitle: String? = nil,
        to chapters: inout [BookChapter]
    ) {
        let content = normalized(text)
        guard !content.isEmpty else { return }
        chapters.append(
            BookChapter(
                title: title,
                content: content,
                index: chapters.count,
                groupTitle: groupTitle
            )
        )
    }

    private func loadDocument(at url: URL) -> LoadedDocument? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let parser = XMLParser(data: data)
        let delegate = EPUBContentXMLParser()
        parser.delegate = delegate
        if parser.parse() {
            let parsedDocument = delegate.document
            guard !normalized(parsedDocument.text).isEmpty else { return nil }
            let title = parsedDocument.headings.first?.title
                ?? url.deletingPathExtension().lastPathComponent
            return LoadedDocument(content: parsedDocument, fallbackTitle: title)
        }
        guard let text = htmlText(from: data), !text.isEmpty else { return nil }
        return LoadedDocument(
            content: EPUBContentDocument(text: text, anchorOffsets: [:], headings: []),
            fallbackTitle: url.deletingPathExtension().lastPathComponent
        )
    }

    private func navigationReferences(
        package: EPUBPackageXMLParser,
        baseURL: URL
    ) -> [NavigationReference] {
        let navigationItem = package.manifest.values.first(where: { $0.properties.contains("nav") })
            ?? package.manifest.values.first(where: {
                $0.mediaType == "application/x-dtbncx+xml"
            })
        guard let navigationItem else { return [] }
        let navigationURL = resolvedURL(for: navigationItem.href, relativeTo: baseURL)
        guard let parser = XMLParser(contentsOf: navigationURL) else { return [] }
        let delegate = EPUBNavigationXMLParser()
        parser.delegate = delegate
        guard parser.parse() else { return [] }
        let navigationBase = navigationURL.deletingLastPathComponent()
        return delegate.links.map { link in
            let reference = resolvedReference(for: link.href, relativeTo: navigationBase)
            return NavigationReference(
                path: reference.url.standardizedFileURL.path,
                fragment: reference.fragment,
                title: link.title,
                groupTitle: link.groupTitle
            )
        }
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

    private func resolvedReference(
        for href: String,
        relativeTo baseURL: URL
    ) -> (url: URL, fragment: String?) {
        let parts = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let rawPath = String(parts[0])
        let path = rawPath.removingPercentEncoding ?? rawPath
        let fragment: String?
        if parts.count > 1 {
            let rawFragment = String(parts[1])
            fragment = rawFragment.removingPercentEncoding ?? rawFragment
        } else {
            fragment = nil
        }
        return (baseURL.appendingPathComponent(path).standardizedFileURL, fragment)
    }

    private func resolvedURL(for href: String, relativeTo baseURL: URL) -> URL {
        resolvedReference(for: href, relativeTo: baseURL).url
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
        return normalized(attributed.string)
    }

    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: #"[\t ]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n\s*\n(?:\s*\n)+"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
