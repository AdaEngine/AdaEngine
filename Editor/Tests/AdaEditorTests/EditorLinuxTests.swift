#if os(Linux)
import AdaEngine
import Foundation
import Testing

@testable import AdaEditor

@Suite("Linux Studio Standalone")
struct EditorLinuxTests {
    @Test @MainActor func nativeDestinationAndDistribution() throws {
        #expect(EditorDistribution.current == .standalone)
        #expect(EditorDistribution.current.supportsSwiftProjects)
        #expect(EditorRunDestination.availableCases == [.linux])
        #expect(KeyModifier.command == .control)
        #expect(EditorRunDestination.linux.adaProjectDestination == .linux)
        #expect(EditorViewModel.editorRunDestination(from: .linux) == .linux)
        let data = try JSONEncoder().encode(AdaProjectRunDestination.linux)
        #expect(try JSONDecoder().decode(AdaProjectRunDestination.self, from: data) == .linux)
    }

    @Test func packagedSDKUsesExecutableDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Studio Linux \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let sdk = root.appendingPathComponent("BuildSDK")
        for directory in ["AdaEngine", "AdaScript/tools"] {
            try FileManager.default.createDirectory(at: sdk.appendingPathComponent(directory), withIntermediateDirectories: true)
        }
        try Data("{\"schemaVersion\":1}".utf8).write(to: sdk.appendingPathComponent("sdk.json"))
        for file in ["AdaEngine/Package.swift", "AdaScript/Package.swift", "AdaScript/tools/aot_build.py"] {
            try Data().write(to: sdk.appendingPathComponent(file))
        }
        let compiler = sdk.appendingPathComponent("AdaScript/gravity")
        try Data("#!/bin/sh\nprintf 'Linux compiler\\n'\n".utf8).write(to: compiler)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: compiler.path)
        let executable = root.appendingPathComponent("AdaEditor")
        let installed = try EditorBuildSDK.locate(executable: executable, environment: [:])
        #expect(installed.engineRoot == sdk.appendingPathComponent("AdaEngine"))
        #expect(EditorEngineSource.locate(executable: executable, environment: [:]) == installed.engineRoot)
        let result = await EditorProcessRunner().run(.init(executablePath: compiler.path, arguments: [], workingDirectory: root))
        #expect(result.succeeded)
        #expect(result.standardOutput == "Linux compiler\n")
    }
}
#endif
