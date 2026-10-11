@testable import AdaEditor
import Foundation
import Testing

@Suite("Example catalog downloads")
struct EditorExampleCatalogTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ExampleTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static let catalogData = Data("""
    {"schemaVersion":1,"items":[{
      "id":"arena","kind":"sample","title":"Arena","description":"A game","path":"Samples/Arena",
      "preview":"Assets/Previews/arena.png","archive":"Arena.zip","tags":["AdaScript","2D","Desktop"]
    }]}
    """.utf8)

    @Test("Local downloads copy real project files, omit generated state and refuse overwrite")
    func localDownload() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appendingPathComponent("Samples/Arena")
        for name in [".ada", ".ada/workspace", "Sources", "dist", ".build", "Nested/.ada/workspace", "script"] {
            try FileManager.default.createDirectory(at: project.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try Self.catalogData.write(to: root.appendingPathComponent("catalog.json"))
        for name in [".ada/project.json", "Sources/Game.ada", ".ada/workspace/session.json", "dist/game", ".build/cache", "Nested/.ada/workspace/session.json", "script/run.sh"] {
            try Data(name.utf8).write(to: project.appendingPathComponent(name))
        }
        let service = EditorExampleService(localRoot: root)
        let item = try #require(try await service.load().items.first)
        let result = try await service.download(item, to: root)
        #expect(try Data(contentsOf: result.appendingPathComponent("Sources/Game.ada")) == Data("Sources/Game.ada".utf8))
        #expect(FileManager.default.fileExists(atPath: result.appendingPathComponent(".ada/project.json").path))
        #expect(!FileManager.default.fileExists(atPath: result.appendingPathComponent(".ada/workspace").path))
        #expect(!FileManager.default.fileExists(atPath: result.appendingPathComponent("dist").path))
        #expect(!FileManager.default.fileExists(atPath: result.appendingPathComponent("Nested/.ada/workspace").path))
        await #expect(throws: EditorExampleError.self) { try await service.download(item, to: root) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix(".ada-example-") }.isEmpty)
    }

    @Test("Remote files use the same pinned commit as the catalog")
    func pinnedRemoteDownload() async throws {
        let revision = String(repeating: "a", count: 40)
        let metadata = Data("{\"schemaVersion\":3}".utf8)
        let service = EditorExampleService { url, _ in
            if url.path == "/repos/AdaEngine/AdaExamples/commits/main" {
                return Data("{\"sha\":\"\(revision)\"}".utf8)
            }
            if url.path == "/AdaEngine/AdaExamples/\(revision)/catalog.json" {
                return Self.catalogData
            }
            if url.path == "/repos/AdaEngine/AdaExamples/git/trees/\(revision)" {
                return Data("""
                {"truncated":false,"tree":[
                  {"path":"Samples/Arena/.ada/project.json","type":"blob","mode":"100644","size":\(metadata.count)},
                  {"path":"Samples/Arena/Sources/Game.ada","type":"blob","mode":"100644","size":4}
                ]}
                """.utf8)
            }
            if url.path == "/AdaEngine/AdaExamples/\(revision)/Samples/Arena/.ada/project.json" {
                return metadata
            }
            if url.path == "/AdaEngine/AdaExamples/\(revision)/Samples/Arena/Sources/Game.ada" {
                return Data("game".utf8)
            }
            throw EditorExampleError("Unexpected or unpinned request: \(url)")
        }
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let item = try #require(try await service.load().items.first)
        let project = try await service.download(item, to: root)
        #expect(try Data(contentsOf: project.appendingPathComponent(".ada/project.json")) == metadata)
    }

    @Test("Failed downloads leave neither partial projects nor temporary folders")
    func failureCleanup() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try Self.catalogData.write(to: root.appendingPathComponent("catalog.json"))
        let project = root.appendingPathComponent("Samples/Arena/Sources")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try Data("game".utf8).write(to: project.appendingPathComponent("Game.ada"))
        let service = EditorExampleService(localRoot: root)
        let item = try #require(try await service.load().items.first)
        await #expect(throws: EditorExampleError.self) { try await service.download(item, to: root) }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("arena").path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix(".ada-example-") }.isEmpty)
    }

    @Test("Downloads reject local symbolic links")
    func symbolicLink() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try Self.catalogData.write(to: root.appendingPathComponent("catalog.json"))
        let project = root.appendingPathComponent("Samples/Arena/.ada")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: project.appendingPathComponent("project.json"), withDestinationURL: root.appendingPathComponent("catalog.json"))
        let service = EditorExampleService(localRoot: root)
        let item = try #require(try await service.load().items.first)
        await #expect(throws: EditorExampleError.self) { try await service.download(item, to: root) }
    }

    @Test(arguments: ["../Game", "/tmp/game", "Samples/../game", "Samples//game", "Samples/game%2fother", "Samples/game?x", "Samples/game\\file"])
    func rejectsUnsafePaths(_ path: String) {
        #expect(!EditorExampleService.safePath(path))
    }

    @Test("Unsupported catalog versions, duplicate IDs and unsafe project paths are rejected")
    func invalidCatalog() throws {
        let source = try #require(String(data: Self.catalogData, encoding: .utf8))
        let valid = try JSONDecoder().decode(EditorExampleCatalog.self, from: Self.catalogData)
        let item = try #require(valid.items.first)
        #expect(throws: EditorExampleError.self) { try EditorExampleCatalog(schemaVersion: 1, items: [item, item]).validate() }
        for replacement in [
            source.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2"),
            source.replacingOccurrences(of: "Samples/Arena", with: "Samples/../Arena"),
        ] {
            let catalog = try JSONDecoder().decode(EditorExampleCatalog.self, from: Data(replacement.utf8))
            #expect(throws: EditorExampleError.self) { try catalog.validate() }
        }
    }
}
