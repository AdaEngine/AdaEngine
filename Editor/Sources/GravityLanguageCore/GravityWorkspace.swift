import Foundation

public final class GravityWorkspace {
    private struct Document {
        var analysis: GravityDocumentAnalysis
        var text: String
        var version: Int?
    }

    private let fileManager: FileManager
    private let languageService = GravityLanguageService()
    private var diskDocuments: [String: Document] = [:]
    private var openDocuments: [String: Document] = [:]
    private var rootURLs: [URL] = []

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func configure(rootURIs: [String]) {
        rootURLs = rootURIs.compactMap(Self.fileURL(from:))
        openDocuments.removeAll(keepingCapacity: true)
        reloadDiskDocuments()
    }

    public func open(uri: String, text: String, version: Int?) {
        openDocuments[uri] = document(text: text, version: version)
    }

    public func change(uri: String, text: String, version: Int?) {
        openDocuments[uri] = document(text: text, version: version)
    }

    public func close(uri: String) {
        openDocuments.removeValue(forKey: uri)
        if let url = Self.fileURL(from: uri), let text = try? String(contentsOf: url, encoding: .utf8) {
            diskDocuments[uri] = document(text: text, version: nil)
        } else {
            diskDocuments.removeValue(forKey: uri)
        }
    }

    public func save(uri: String, text: String?) {
        if let text {
            if let document = openDocuments[uri] {
                openDocuments[uri] = self.document(text: text, version: document.version)
            }
            diskDocuments[uri] = document(text: text, version: nil)
        } else if let url = Self.fileURL(from: uri), let diskText = try? String(contentsOf: url, encoding: .utf8) {
            diskDocuments[uri] = document(text: diskText, version: nil)
        }
    }

    public func text(for uri: String) -> String? {
        openDocuments[uri]?.text ?? diskDocuments[uri]?.text
    }

    public func analysis(for uri: String) -> GravityDocumentAnalysis? {
        openDocuments[uri]?.analysis ?? diskDocuments[uri]?.analysis
    }

    public func completions(uri: String, position: GravitySourcePosition) -> [GravityCompletion] {
        guard let text = text(for: uri) else {
            return []
        }
        return languageService.completions(
            text: text,
            position: position,
            workspaceSymbols: workspaceSymbols(excluding: uri)
        )
    }

    public func refreshFile(uri: String) {
        guard openDocuments[uri] == nil,
              let url = Self.fileURL(from: uri),
              Self.isGravitySource(url),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return
        }
        diskDocuments[uri] = document(text: text, version: nil)
    }

    public func removeFile(uri: String) {
        guard openDocuments[uri] == nil else {
            return
        }
        diskDocuments.removeValue(forKey: uri)
    }

    private func workspaceSymbols(excluding excludedURI: String) -> [GravitySymbol] {
        var symbols: [GravitySymbol] = []
        for (uri, document) in mergedDocuments() where uri != excludedURI {
            symbols += document.analysis.symbols
        }
        return symbols
    }

    private func mergedDocuments() -> [String: Document] {
        var documents = diskDocuments
        for (uri, document) in openDocuments {
            documents[uri] = document
        }
        return documents
    }

    private func document(text: String, version: Int?) -> Document {
        Document(analysis: languageService.analyze(text: text), text: text, version: version)
    }

    private func reloadDiskDocuments() {
        diskDocuments.removeAll(keepingCapacity: true)
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        for rootURL in rootURLs {
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for case let fileURL as URL in enumerator {
                if Self.skippedDirectoryNames.contains(fileURL.lastPathComponent),
                   (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                    continue
                }
                guard Self.isGravitySource(fileURL),
                      (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                      let text = try? String(contentsOf: fileURL, encoding: .utf8)
                else {
                    continue
                }
                diskDocuments[fileURL.absoluteString] = document(text: text, version: nil)
            }
        }
    }

    private static let skippedDirectoryNames: Set<String> = [".ada", ".build", ".git", ".swiftpm", "DerivedData"]

    private static func fileURL(from uri: String) -> URL? {
        guard let url = URL(string: uri), url.isFileURL else {
            return nil
        }
        return url.standardizedFileURL
    }

    private static func isGravitySource(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        return pathExtension == "ada" || pathExtension == "gravity"
    }
}
