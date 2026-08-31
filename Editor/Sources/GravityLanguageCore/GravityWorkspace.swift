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
        openDocuments[Self.documentKey(uri)] = document(text: text, version: version)
    }

    public func change(uri: String, text: String, version: Int?) {
        openDocuments[Self.documentKey(uri)] = document(text: text, version: version)
    }

    public func close(uri: String) {
        let key = Self.documentKey(uri)
        openDocuments.removeValue(forKey: key)
        if let url = Self.fileURL(from: uri), let text = try? String(contentsOf: url, encoding: .utf8) {
            diskDocuments[key] = document(text: text, version: nil)
        } else {
            diskDocuments.removeValue(forKey: key)
        }
    }

    public func save(uri: String, text: String?) {
        let key = Self.documentKey(uri)
        if let text {
            if let document = openDocuments[key] {
                openDocuments[key] = self.document(text: text, version: document.version)
            }
            diskDocuments[key] = document(text: text, version: nil)
        } else if let url = Self.fileURL(from: uri), let diskText = try? String(contentsOf: url, encoding: .utf8) {
            diskDocuments[key] = document(text: diskText, version: nil)
        }
    }

    public func text(for uri: String) -> String? {
        let key = Self.documentKey(uri)
        return openDocuments[key]?.text ?? diskDocuments[key]?.text
    }

    public func analysis(for uri: String) -> GravityDocumentAnalysis? {
        let key = Self.documentKey(uri)
        guard var analysis = (openDocuments[key] ?? diskDocuments[key])?.analysis else {
            return nil
        }
        analysis.diagnostics += importDiagnostics(uri: key, imports: analysis.imports)
        return analysis
    }

    public func completions(uri: String, position: GravitySourcePosition) -> [GravityCompletion] {
        guard let text = text(for: uri) else {
            return []
        }
        return languageService.completions(
            text: text,
            position: position,
            workspaceSymbols: importedSymbols(for: uri)
        )
    }

    public func refreshFile(uri: String) {
        let key = Self.documentKey(uri)
        guard openDocuments[key] == nil,
              let url = Self.fileURL(from: uri),
              Self.isGravitySource(url),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return
        }
        diskDocuments[key] = document(text: text, version: nil)
    }

    public func removeFile(uri: String) {
        let key = Self.documentKey(uri)
        guard openDocuments[key] == nil else {
            return
        }
        diskDocuments.removeValue(forKey: key)
    }

    private func importedSymbols(for uri: String) -> [GravitySymbol] {
        let key = Self.documentKey(uri)
        guard let document = openDocuments[key] ?? diskDocuments[key] else {
            return []
        }
        var symbols: [GravitySymbol] = []
        for scriptImport in document.analysis.imports {
            guard case .source(_, let importedDocument) = resolve(scriptImport, from: key) else {
                continue
            }
            if let namespace = scriptImport.namespace {
                symbols.append(GravitySymbol(
                    name: namespace,
                    kind: .class,
                    detail: "Imported Ada Script module",
                    range: scriptImport.range,
                    members: importedDocument.analysis.symbols
                ))
            } else {
                let selectedNames = Set(scriptImport.names)
                symbols += importedDocument.analysis.symbols.filter { selectedNames.contains($0.name) }
            }
        }
        return symbols
    }

    private func importDiagnostics(uri: String, imports: [GravityImport]) -> [GravityDiagnostic] {
        imports.compactMap { scriptImport in
            switch resolve(scriptImport, from: uri) {
            case .source, .virtual:
                nil
            case .invalid(let message):
                GravityDiagnostic(message: message, range: scriptImport.range)
            }
        }
    }

    private func resolve(_ scriptImport: GravityImport, from importerURI: String) -> ImportResolution {
        if Self.virtualModuleNames.contains(scriptImport.path) {
            return .virtual
        }
        guard scriptImport.path.hasPrefix("./") || scriptImport.path.hasPrefix("../") else {
            return .invalid("Imports must be relative or name a supported virtual module")
        }
        guard let importerURL = Self.fileURL(from: importerURI) else {
            return .invalid("Unable to resolve import from a non-file document")
        }

        var importedURL = importerURL.deletingLastPathComponent()
            .appendingPathComponent(scriptImport.path)
            .standardizedFileURL
        if importedURL.pathExtension.isEmpty {
            importedURL.appendPathExtension("ada")
        }
        guard rootURLs.contains(where: { Self.contains(importedURL, in: $0) }) else {
            return .invalid("Import escapes the configured Ada Script workspace")
        }

        let importedURI = importedURL.absoluteString
        guard let document = openDocuments[importedURI] ?? diskDocuments[importedURI] else {
            return .invalid("Unable to resolve import '\(scriptImport.path)'")
        }
        return .source(importedURI, document)
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
                diskDocuments[fileURL.standardizedFileURL.absoluteString] = document(text: text, version: nil)
            }
        }
    }

    private static let skippedDirectoryNames: Set<String> = [".ada", ".build", ".git", ".swiftpm", "DerivedData"]
    private static let virtualModuleNames: Set<String> = ["AdaEngine", "AdaUI"]

    private static func contains(_ fileURL: URL, in rootURL: URL) -> Bool {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        return filePath == rootPath || filePath.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    private static func fileURL(from uri: String) -> URL? {
        guard let url = URL(string: uri), url.isFileURL else {
            return nil
        }
        return url.standardizedFileURL
    }

    private static func documentKey(_ uri: String) -> String {
        fileURL(from: uri)?.absoluteString ?? uri
    }

    private static func isGravitySource(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        return pathExtension == "ada" || pathExtension == "gravity"
    }

    private enum ImportResolution {
        case invalid(String)
        case source(String, Document)
        case virtual
    }
}
