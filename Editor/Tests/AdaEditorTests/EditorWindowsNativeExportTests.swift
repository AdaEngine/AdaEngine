#if os(Windows)
@_spi(Internal) @testable import AdaApp
import AdaEngine
import AdaScriptCompilerCore
import Foundation
import Testing
@testable import AdaEditor

@Suite("Windows native export preparation", .serialized)
@MainActor
struct EditorWindowsNativeExportTests {
    @Test("Static state selects the editor-compatible VM without matching comments or strings")
    func staticRuntimeSelection() {
        #expect(AdaScriptNativeSourceBuilder.requiresInterpretedRuntime(sources: [
            .init(path: "State.ada", source: "class State { static var count = 0; }")
        ]))
        #expect(!AdaScriptNativeSourceBuilder.requiresInterpretedRuntime(sources: [
            .init(path: "Main.ada", source: "// static var count = 0;\nfunc label() { return \"static\"; }")
        ]))
    }

    @Test("Exported static state uses the full VM and persists across system updates")
    func preparesStaticGame() async throws {
        EditorComponentRegistry.registerBuiltIns()
        let sdk = try EditorBuildSDK.locate()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AdaStaticExport-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Assets"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sources = [
            AdaScriptSource(path: "State.ada", source: "class Counter { static var value = 0; static func next() { Counter.value += 1; return Counter.value; } }"),
            AdaScriptSource(path: "Tick.ada", source: """
            import { Counter } from "./State.ada";
            @system(scheduler: "update", id: "counter.tick")
            class Tick {
                @query(Transform) var rows;
                func update(context) { for (var row in rows) { row.transform.position = [Counter.next(), 0, 0]; } }
            }
            """)
        ]
        for source in sources {
            try source.source.write(to: root.appendingPathComponent("Sources/" + source.path), atomically: true, encoding: .utf8)
        }
        var project = try ProjectSystem.createDefaultProject(at: root, buildSystem: .adaScript)
        project.runtime.entry.view = nil
        project.runtime.entry.scene = "Main.ascn"
        try EditorSceneModel.default(projectName: "Static game").encodedYAML().write(
            to: root.appendingPathComponent("Assets/Main.ascn"), atomically: true, encoding: .utf8
        )
        var options = EditorAdaScriptNativeExportOptions(destination: .web, gravityRoot: sdk.compilerRoot, engineRoot: sdk.engineRoot, swiftExecutable: "")
        options.buildsPlayer = false
        let result = try await EditorAdaScriptNativeExporter().export(project: project, at: root, to: root.appendingPathComponent("Export"), options: options)
        let report = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: result.appendingPathComponent("ada-native-export.json"))) as? [String: Any])
        #expect(report["runtime"] as? String == "interpreted")
        #expect(!FileManager.default.fileExists(atPath: result.appendingPathComponent("Sources/GameplayNative").path))
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin())
        let plugin = try AdaScriptPlugin(sources: sources, name: "Static game")
        app.addPlugin(plugin)
        let entity = app.main.spawn("Counter")
        entity.components += Transform()
        try await app.build()
        await app.main.runScheduler(.update, deltaTime: 1 / 60)
        await app.main.runScheduler(.update, deltaTime: 1 / 60)
        #expect(entity.components[Transform.self]?.position.x == 2)
        #expect(plugin.diagnostics.isEmpty)
    }

    @Test("Prepare the optional live cross-platform validation project",
          .enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_WINDOWS_EXPORT_PROJECT"] != nil),
          arguments: [EditorAdaScriptNativeExportOptions.Destination.web, .android])
    func preparesLiveProject(destination: EditorAdaScriptNativeExportOptions.Destination) async throws {
        let path = try #require(ProcessInfo.processInfo.environment["ADAENGINE_WINDOWS_EXPORT_PROJECT"])
        let root = URL(fileURLWithPath: path)
        let project = try ProjectSystem.loadProject(at: root)
        let sdk = try EditorBuildSDK.locate()
        var options = EditorAdaScriptNativeExportOptions(destination: destination, gravityRoot: sdk.compilerRoot,
                                                         engineRoot: sdk.engineRoot, swiftExecutable: "")
        options.buildsPlayer = false
        _ = try await EditorAdaScriptNativeExporter().export(
            project: project, at: root, to: root.appendingPathComponent("Exports/Prepared" + (destination == .web ? "Web" : "Android")), options: options
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
        try """
        import { answer as renamed } from "./ZLibrary.ada";
        import * as Library from "./ZLibrary.ada";
        func main() { return renamed() + Library.answer(); }
        """.write(to: root.appendingPathComponent("Sources/Main.ada"), atomically: true, encoding: .utf8)
        try "func answer() { return 42; }".write(
            to: root.appendingPathComponent("Sources/ZLibrary.ada"), atomically: true, encoding: .utf8
        )
        var scene = EditorSceneModel.default(projectName: "Windows export")
        let lightName = String(reflecting: DirectionalLightComponent.self)
        scene.entities[0].components[lightName] = [
            "radiance": .array([.double(0.8), .double(0.7), .double(0.6)]),
            "intensity": .double(3), "castShadows": .bool(false), "shadowDistance": .double(45),
            "shadowBias": .double(0.002), "shadowSlopeBias": .double(0.005)
        ]
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
        let lightData = try #require(prepared.entities.first?.components[lightName])
        let light = try JSONDecoder().decode(DirectionalLightComponent.self, from: lightData)
        #expect(light.radiance == Vector3(0.8, 0.7, 0.6))
        #expect(light.intensity == 3 && !light.castShadows && light.shadowDistance == 45)
        #expect(light.shadowBias == 0.002 && light.shadowSlopeBias == 0.005)
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
