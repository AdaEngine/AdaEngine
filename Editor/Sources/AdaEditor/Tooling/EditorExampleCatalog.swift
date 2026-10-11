import Foundation

struct EditorExampleCatalog: Decodable, Sendable {
    struct Item: Decodable, Identifiable, Equatable, Sendable {
        let id: String
        let kind: String
        let title: String
        let description: String
        let path: String
        let preview: String
        let archive: String
        let tags: [String]

        var requiresSwift: Bool { tags.contains("Swift") }
    }

    let schemaVersion: Int
    let items: [Item]

    func validate() throws {
        guard schemaVersion == 1, items.count <= 200, Set(items.map(\.id)).count == items.count,
              Set(items.map(\.path)).count == items.count else {
            throw EditorExampleError("Invalid examples catalog.")
        }
        for item in items {
            guard item.id.range(of: #"^[a-z0-9]+(?:-[a-z0-9]+)*$"#, options: .regularExpression) != nil,
                  EditorExampleService.safePath(item.path),
                  item.path.hasPrefix(item.kind == "sample" ? "Samples/" : "Examples/"),
                  ["sample", "example"].contains(item.kind), !item.title.isEmpty, !item.tags.isEmpty else {
                throw EditorExampleError("Invalid example: \(item.id).")
            }
        }
    }
}

struct EditorExampleError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Materializes one project from a pinned repository revision, without subprocesses or archive extraction.
actor EditorExampleService {
    typealias Fetch = @Sendable (URL, Int) async throws -> Data
    static let repository = "AdaEngine/AdaExamples"
    private let localRoot: URL?
    private let fetch: Fetch
    private var revision: String?
    private var catalog: EditorExampleCatalog?

    init(localRoot: URL? = nil, fetch: @escaping Fetch = EditorExampleService.fetchHTTPS) {
        self.localRoot = localRoot
        self.fetch = fetch
    }

    static func configured() -> EditorExampleService {
        let root = ProcessInfo.processInfo.environment["ADAEXAMPLES_PATH"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        return EditorExampleService(localRoot: root)
    }

    func load() async throws -> EditorExampleCatalog {
        let data: Data
        var pinnedRevision: String?
        if let localRoot {
            data = try Data(contentsOf: localRoot.appendingPathComponent("catalog.json"))
        } else {
            struct Commit: Decodable { let sha: String }
            let commit = try JSONDecoder().decode(Commit.self, from: await fetch(url("https://api.github.com/repos/\(Self.repository)/commits/main"), 1_000_000))
            guard commit.sha.range(of: #"^[0-9a-f]{40}$"#, options: .regularExpression) != nil else {
                throw EditorExampleError("Invalid examples revision.")
            }
            data = try await fetch(url("https://raw.githubusercontent.com/\(Self.repository)/\(commit.sha)/catalog.json"), 2_000_000)
            pinnedRevision = commit.sha
        }
        let result = try JSONDecoder().decode(EditorExampleCatalog.self, from: data)
        try result.validate()
        revision = pinnedRevision
        catalog = result
        return result
    }

    func download(_ item: EditorExampleCatalog.Item, to parent: URL) async throws -> URL {
        guard catalog?.items.contains(item) == true else { throw EditorExampleError("Refresh the examples catalog before downloading.") }
        let manager = FileManager()
        let destination = parent.appendingPathComponent(item.id, isDirectory: true)
        guard !manager.fileExists(atPath: destination.path) else { throw EditorExampleError("A folder named \(item.id) already exists. Choose another location.") }
        // Stage beside the final destination; failures never leave a partial project or overwrite a user's copy.
        let staging = parent.appendingPathComponent(".ada-example-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: staging) }
        let files: [(String, Data, Bool)]
        if let localRoot {
            files = try localFiles(item, root: localRoot, manager: manager)
        } else {
            files = try await remoteFiles(item)
        }
        guard files.contains(where: { $0.0 == ".ada/project.json" }) else { throw EditorExampleError("The example has no Ada project metadata.") }
        for (path, data, executable) in files {
            try Task.checkCancellation()
            let target = staging.appendingPathComponent(path)
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
            #if !os(Windows)
                if executable { try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path) }
            #endif
        }
        try manager.moveItem(at: staging, to: destination)
        return destination
    }

    private func localFiles(_ item: EditorExampleCatalog.Item, root: URL, manager: FileManager) throws -> [(String, Data, Bool)] {
        let source = root.resolvingSymlinksInPath().appendingPathComponent(item.path).standardizedFileURL
        guard source.resolvingSymlinksInPath().path == source.path else { throw EditorExampleError("Example directories must not be symbolic links.") }
        guard let entries = manager.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) else {
            throw EditorExampleError("The example folder is missing.")
        }
        var files: [(String, Data, Bool)] = [], total = 0
        for case let file as URL in entries {
            let path = String(file.resolvingSymlinksInPath().path.dropFirst(source.path.count + 1))
            if Self.excluded(path) { entries.skipDescendants(); continue }
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true else { throw EditorExampleError("Example files must not be symbolic links.") }
            guard values.isRegularFile == true else { continue }
            try Self.checkSize(values.fileSize ?? 0, total: &total, count: files.count)
            files.append((path, try Data(contentsOf: file), manager.isExecutableFile(atPath: file.path)))
        }
        return files
    }

    private func remoteFiles(_ item: EditorExampleCatalog.Item) async throws -> [(String, Data, Bool)] {
        struct Tree: Decodable {
            struct Entry: Decodable { let path: String; let type: String; let mode: String; let size: Int? }
            let truncated: Bool
            let tree: [Entry]
        }
        guard let revision else { throw EditorExampleError("Refresh the examples catalog.") }
        let tree = try JSONDecoder().decode(Tree.self, from: await fetch(url("https://api.github.com/repos/\(Self.repository)/git/trees/\(revision)?recursive=1"), 8_000_000))
        guard !tree.truncated else { throw EditorExampleError("The examples repository is too large to download safely.") }
        let prefix = item.path + "/"
        var files: [(String, Data, Bool)] = [], total = 0
        for entry in tree.tree where entry.path.hasPrefix(prefix) && entry.type != "tree" {
            let path = String(entry.path.dropFirst(prefix.count))
            if Self.excluded(path) { continue }
            guard Self.safePath(path), entry.type == "blob", ["100644", "100755"].contains(entry.mode), let size = entry.size else {
                throw EditorExampleError("The example contains an unsupported file.")
            }
            try Self.checkSize(size, total: &total, count: files.count)
            try Task.checkCancellation()
            let data = try await fetch(url("https://raw.githubusercontent.com/\(Self.repository)/\(revision)/\(entry.path)"), max(1, size))
            guard data.count == size else { throw EditorExampleError("Incomplete example download.") }
            files.append((path, data, entry.mode == "100755"))
        }
        return files
    }

    static func safePath(_ path: String) -> Bool {
        !path.isEmpty && !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) && !path.hasPrefix("/") && !path.contains("\\") && !path.contains(":")
            && !path.contains("%") && !path.contains("?") && !path.contains("#")
            && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    static func excluded(_ path: String) -> Bool {
        let parts = path.split(separator: "/")
        return parts.contains { [".git", ".build", ".swiftpm", ".codegraph", "dist", ".DS_Store", "__pycache__"].contains(String($0)) || $0.hasSuffix(".xcodeproj") }
            || zip(parts, parts.dropFirst()).contains { $0 == ".ada" && $1 == "workspace" }
    }

    private static func checkSize(_ size: Int, total: inout Int, count: Int) throws {
        guard size >= 0, size <= 64_000_000, total <= 300_000_000 - size, count < 5_000 else {
            throw EditorExampleError("The example exceeds the download limit.")
        }
        total += size
    }

    private func url(_ value: String) throws -> URL {
        guard let url = URL(string: value) else { throw EditorExampleError("Invalid examples URL.") }
        return url
    }

    static func fetchHTTPS(_ url: URL, limit: Int) async throws -> Data {
        let (bytes, response) = try await URLSession.shared.bytes(for: URLRequest(url: url, timeoutInterval: 120))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url?.scheme == "https",
              http.expectedContentLength <= limit else { throw EditorExampleError("Examples are unavailable. Check your connection and try again.") }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw EditorExampleError("Example download exceeds the size limit.") }
            data.append(byte)
        }
        guard http.expectedContentLength < 0 || data.count == http.expectedContentLength else { throw EditorExampleError("Incomplete example download.") }
        return data
    }
}
