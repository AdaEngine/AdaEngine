#if (os(macOS) || os(Windows)) && canImport(GravityAOT)
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
                swiftExecutable: EditorHostTools.executable("swift")
            )
            #if os(macOS)
            options.buildsPlayer = destination == .macOS && environment["ADAENGINE_SHADER_GRAPH_EXPORT_BUILD_NATIVE"] == "1"
            #else
            options.buildsPlayer = false
            #endif
            options.scratchDirectory = environment["ADAENGINE_SHADER_GRAPH_NATIVE_SCRATCH"].map { URL(fileURLWithPath: $0) }
            options.configuration = .debug
            let result = try await exporter.export(project: project, at: root, to: output.appendingPathComponent(destination.rawValue), options: options)
            let assets = result.appendingPathComponent("Sources/AdaNativeGame/GameAssets")
            let graphPath = "Effects/Tint.shadergraph"
            if FileManager.default.fileExists(atPath: root.appendingPathComponent("Assets/" + graphPath).path) {
                let graph = try JSONDecoder().decode(ShaderGraph.self, from: Data(contentsOf: assets.appendingPathComponent(graphPath)))
                #expect(graph.target == .sprite)
            } else {
                #expect(!FileManager.default.fileExists(atPath: assets.appendingPathComponent(graphPath).path))
            }
            let player = try String(contentsOf: result.appendingPathComponent("Sources/AdaNativeGame/Game.swift"), encoding: .utf8)
            #expect(player.contains("preloadedAssetPaths"))
            #expect(!player.contains(root.path))
            #expect(FileManager.default.fileExists(atPath: assets.appendingPathComponent("Scenes/Main.ascn").path))
            let pbrScene = assets.appendingPathComponent("Scenes/PBR.ascn")
            if FileManager.default.fileExists(atPath: pbrScene.path) {
                let scene = try JSONDecoder().decode(AdaScriptNativeSceneDocument.self, from: Data(contentsOf: pbrScene))
                let primitives = try scene.entities.compactMap { item in
                    try item.components[String(reflecting: Mesh3DComponent.self)].map { try JSONDecoder().decode(PrimitiveMesh3DSource.self, from: $0) }
                }
                #expect(Set(primitives.filter { $0.graphMaterial != nil }.map(\.mesh)) == [.quad, .circle, .cube, .sphere, .plane])
                #expect(primitives.filter { $0.graphMaterial != nil }.allSatisfy { $0.castShadows && $0.receiveShadows })
                let models = try scene.entities.compactMap { item in
                    try item.components[String(reflecting: Model3DSource.self)].map { try JSONDecoder().decode(Model3DSource.self, from: $0) }
                }
                #expect(models.count == 2)
                #expect(models.allSatisfy { $0.source.hasPrefix("@res://") && $0.graphMaterials["0"]?.path == "@res://Effects/Surface.shadergraph" })
                #expect(models.first?.graphMaterials["0"]?.values != models.last?.graphMaterials["0"]?.values)
                for source in models {
                    let model = try #require(try await AssetsManager.load(ModelAsset3D.self, at: source.source).asset)
                    #expect(model.meshes.count == 3)
                    let material = try #require(model.materials.first as? PBRMaterial)
                    #expect(material.baseColorTexture != nil && material.normalTexture != nil)
                    let world = World(name: "Portable imported graph material")
                    let root = try source.instantiate(model, in: world, under: world.spawn("Imported model"))
                    #expect(!root.children.isEmpty)
                    let mesh = try #require(root.children.first?.components[Mesh3DComponent.self])
                    let override = try #require(mesh.materials.first as? PBRMaterial)
                    #expect(override.graphMaterial?.value(for: "tint") == source.graphMaterials["0"]?.values["tint"])
                    #expect(override.baseColorTexture === material.baseColorTexture)
                }
            }
        }
    }
}
#endif
