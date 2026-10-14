#if os(Windows)
import AdaEngine
import AdaScriptCompilerCore
import Foundation
import Testing
@testable import AdaEditor

@Suite("Windows native export preparation", .serialized)
@MainActor
struct EditorWindowsNativeExportTests {
    @Test("Prepare the optional live cross-platform validation project",
          .enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_WINDOWS_EXPORT_PROJECT"] != nil))
    func preparesLiveProject() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["ADAENGINE_WINDOWS_EXPORT_PROJECT"])
        let root = URL(fileURLWithPath: path)
        let project = try ProjectSystem.loadProject(at: root)
        let sdk = try EditorBuildSDK.locate()
        var options = EditorAdaScriptNativeExportOptions(destination: .web, gravityRoot: sdk.compilerRoot,
                                                         engineRoot: sdk.engineRoot, swiftExecutable: "")
        options.buildsPlayer = false
        _ = try await EditorAdaScriptNativeExporter().export(
            project: project, at: root, to: root.appendingPathComponent("Exports/PreparedWeb"), options: options
        )
    }

    @Test("The real Windows compiler validates metadata and prepares a portable Web game")
    func preparesNativeGame() async throws {
        let sdk = try EditorBuildSDK.locate()
        print("Native export tools: \(EditorHostTools.executable("python3", windowsName: "python.exe")), \(EditorHostTools.executable("clang"))")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AdaWindowsExport-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Assets"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var project = try ProjectSystem.createDefaultProject(at: root, buildSystem: .adaScript)
        project.runtime.entry.view = nil
        project.runtime.entry.scene = "Main.ascn"
        try "func main() { return 42; }".write(to: root.appendingPathComponent("Sources/Main.ada"), atomically: true, encoding: .utf8)
        let scene = EditorSceneModel.default(projectName: "Windows export")
        try scene.encodedYAML().write(to: root.appendingPathComponent("Assets/Main.ascn"), atomically: true, encoding: .utf8)
        var options = EditorAdaScriptNativeExportOptions(destination: .web, gravityRoot: sdk.compilerRoot,
                                                         engineRoot: sdk.engineRoot, swiftExecutable: "")
        options.buildsPlayer = false
        let output = root.appendingPathComponent("Export")
        let result = try await EditorAdaScriptNativeExporter().export(project: project, at: root, to: output, options: options) { event in
            print(event.text)
        }
        let nativeSource = try String(contentsOf: result.appendingPathComponent("Sources/GameplayNative/ada_game.c"), encoding: .utf8)
        #expect(nativeSource.contains("ada_game_get_module"))
        let prepared = try JSONDecoder().decode(AdaScriptNativeSceneDocument.self,
            from: Data(contentsOf: result.appendingPathComponent("Sources/AdaNativeGame/GameAssets/Main.ascn")))
        #expect(prepared.entities.count == scene.entities.count)
        #expect(FileManager.default.fileExists(atPath: result.appendingPathComponent("ada-native-export.json").path))
        let before = try Data(contentsOf: result.appendingPathComponent("Sources/GameplayNative/ada_game.c"))
        try "class {".write(to: root.appendingPathComponent("Sources/Main.ada"), atomically: true, encoding: .utf8)
        await #expect(throws: (any Error).self) {
            _ = try await EditorAdaScriptNativeExporter().export(project: project, at: root, to: output, options: options)
        }
        #expect(try Data(contentsOf: result.appendingPathComponent("Sources/GameplayNative/ada_game.c")) == before)
    }
}
#endif
