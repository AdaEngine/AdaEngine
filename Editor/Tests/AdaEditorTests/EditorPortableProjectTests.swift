import AdaPackageManifestTool
import Foundation
import Testing

@testable import AdaEditor

@Suite("Portable Studio projects")
struct EditorPortableProjectTests {
    @Test("new hybrid project survives relocation without a build-machine dependency")
    func newProjectSurvivesRelocation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = EditorProjectStore(storageURL: root.appendingPathComponent("projects.json"), distribution: .standalone)
        let project = try store.createProject(named: "PortableGame", at: root)
        let original = URL(fileURLWithPath: project.path)
        let relocated = root.appendingPathComponent("Moved Game")
        try FileManager.default.moveItem(at: original, to: relocated)
        let manifest = try String(contentsOf: relocated.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(store.adaEnginePackageURL == nil)
        #expect(manifest.contains(PackageManifestEditor.adaEngineDependency))
        #expect(!manifest.contains(root.path))
        #expect(!manifest.contains(".package(name: \"AdaEngine\", path:"))
        #expect(try !store.ensureAdaEngineDependency(at: relocated))
        #if os(macOS)
        let result = await EditorProcessRunner().run(EditorProcessCommand(
            executablePath: "/usr/bin/env", arguments: ["swift", "package", "dump-package"], workingDirectory: relocated
        ))
        #expect(result.succeeded, Comment(rawValue: result.combinedOutput))
        #expect(result.standardOutput.contains("https://github.com/AdaEngine/Ada.git"))
        #endif
    }

    @Test("opening a project repairs the path leaked by the release build")
    func openingRepairsBuildMachinePath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = EditorProjectStore(storageURL: root.appendingPathComponent("projects.json"), distribution: .standalone)
        let project = try store.createProject(named: "BrokenGame", at: root)
        let url = URL(fileURLWithPath: project.path)
        let manifestURL = url.appendingPathComponent("Package.swift")
        let original = try String(contentsOf: manifestURL, encoding: .utf8)
        let broken = original.replacingOccurrences(
            of: PackageManifestEditor.adaEngineDependency,
            with: #".package(name: "AdaEngine", path: "/tmp/ada-studio-rebuild-snapshot-20261011/AdaEngine")"#
        )
        try broken.write(to: manifestURL, atomically: true, encoding: .utf8)
        _ = try store.openProject(at: url)
        #expect(try String(contentsOf: manifestURL, encoding: .utf8) == original)
        #expect(try !store.ensureAdaEngineDependency(at: url))
    }

    @Test("remote pinned dependencies retain their revision and package identity", arguments: ["Ada", "AdaEngine"])
    func remoteRevisionIsPreserved(repository: String) throws {
        let manifest = """
        import PackageDescription
        let package = Package(name: "Game", dependencies: [
            .package(url: "https://github.com/AdaEngine/\(repository).git", revision: "abc123")
        ], targets: [.executableTarget(name: "Game", dependencies: [])])
        """
        let result = try PackageManifestEditor.edit(manifest, command: .ensureAdaEngineDependency(targetName: nil))
        #expect(result.manifest.contains(#"revision: "abc123""#))
        #expect(result.manifest.components(separatedBy: ".package(").count == 2)
        #expect(result.manifest.contains(#".product(name: "AdaEngine", package: "\#(repository)")"#))
        #expect(try !PackageManifestEditor.edit(result.manifest, command: .ensureAdaEngineDependency(targetName: nil)).changed)
    }

    @Test("installed engine sources survive app relocation and never fall back to the checkout")
    func installedSourcesSurviveRelocation() throws {
        #if os(macOS)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Studio.app")
        let engine = app.appendingPathComponent("Contents/Resources/BuildSDK/AdaEngine")
        let executable = app.appendingPathComponent("Contents/MacOS/AdaEditor")
        #expect(EditorEngineSource.locate(executable: executable, environment: [:]) == nil)
        try FileManager.default.createDirectory(at: engine, withIntermediateDirectories: true)
        try Data().write(to: engine.appendingPathComponent("Package.swift"))
        #expect(EditorEngineSource.locate(executable: executable, environment: [:])?.path == engine.path)
        let moved = root.appendingPathComponent("Moved Studio.app")
        try FileManager.default.moveItem(at: app, to: moved)
        #expect(EditorEngineSource.locate(executable: executable, environment: [:]) == nil)
        #expect(EditorEngineSource.locate(
            executable: moved.appendingPathComponent("Contents/MacOS/AdaEditor"), environment: [:]
        )?.path == moved.appendingPathComponent("Contents/Resources/BuildSDK/AdaEngine").path)
        #expect(EditorEngineSource.locate(
            executable: moved.appendingPathComponent("Contents/MacOS/AdaEditor"),
            environment: ["ADAENGINE_PACKAGE_PATH": root.appendingPathComponent("Missing").path]
        ) == nil)
        #endif
    }
}
