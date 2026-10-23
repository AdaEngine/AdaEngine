#if os(macOS) && canImport(GravityAOT)
@testable import AdaEditor
import AdaEngine
@testable import AdaRender
import Foundation
import Testing

@MainActor @Suite("Shader Graph export integration", .serialized)
struct EditorShaderGraphExportTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_SHADER_GRAPH_EXPORT_PROJECT"] != nil))
    func emitsNativeAndWebPlayersWithPortableGraphResources() async throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        let environment = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(environment["ADAENGINE_SHADER_GRAPH_EXPORT_PROJECT"]))
        let output = URL(fileURLWithPath: try #require(environment["ADAENGINE_SHADER_GRAPH_EXPORT_OUTPUT"]))
        let engine = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let project = try JSONDecoder().decode(AdaProject.self, from: Data(contentsOf: root.appendingPathComponent(".ada/project.json")))
        await AssetsManager.setProjectDirectories(.init(source: root, assetsDirectory: root.appendingPathComponent("Assets")))
        let exporter = EditorAdaScriptNativeExporter(distribution: .standalone)
        for destination in [EditorAdaScriptNativeExportOptions.Destination.macOS, .web] {
            var options = EditorAdaScriptNativeExportOptions(
                destination: destination,
                gravityRoot: engine.appendingPathComponent("Sources/gravity-lang"),
                engineRoot: engine,
                swiftExecutable: "/usr/bin/swift"
            )
            options.buildsPlayer = destination == .macOS && environment["ADAENGINE_SHADER_GRAPH_EXPORT_BUILD_NATIVE"] == "1"
            options.scratchDirectory = environment["ADAENGINE_SHADER_GRAPH_NATIVE_SCRATCH"].map { URL(fileURLWithPath: $0) }
            options.configuration = .debug
            let result = try await exporter.export(project: project, at: root, to: output.appendingPathComponent(destination.rawValue), options: options)
            let assets = result.appendingPathComponent("Sources/AdaNativeGame/GameAssets")
            let graph = try JSONDecoder().decode(ShaderGraph.self, from: Data(contentsOf: assets.appendingPathComponent("Effects/Tint.shadergraph")))
            #expect(graph.target == .sprite)
            let player = try String(contentsOf: result.appendingPathComponent("Sources/AdaNativeGame/Game.swift"), encoding: .utf8)
            #expect(player.contains("preloadedAssetPaths"))
            #expect(!player.contains(root.path))
            #expect(FileManager.default.fileExists(atPath: assets.appendingPathComponent("Scenes/Main.ascn").path))
        }
    }
}
#endif
