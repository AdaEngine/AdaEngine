@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import Foundation
import Testing

@MainActor @Suite("Shader Graph scene resource scope", .serialized)
struct EditorShaderGraphResourceTests {
    @Test func importedModelOverridesSurviveTheEditorComponentDecoder() throws {
        EditorComponentRegistry.registerBuiltIns()
        let graph = EditorShaderGraphTemplates.basic(target: .pbrSurface)
        var authored = Model3DSource(source: "@res://Models/Test.glb")
        authored.graphMaterials = ["0": .init(graph: graph, values: ["tint": [0.1, 0.5, 0.8, 1]], textures: ["map": "@res://цвет.png"])]
        let payload = try JSONDecoder().decode(EditorComponentPayload.self, from: JSONEncoder().encode(authored))
        let restored = try #require(try EditorComponentRegistry.decode(typeName: EditorBuiltInComponentType.model3DSource, payload: payload) as? Model3DSource)
        #expect(restored == authored)
        let portable = try JSONDecoder().decode(Model3DSource.self, from: JSONEncoder().encode(restored))
        #expect(portable.graphMaterials == authored.graphMaterials)
    }

    @Test func sceneLoadsVirtualGraphBeforeAssetPluginsStart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GraphScene-\(UUID().uuidString)")
        let assets = root.appendingPathComponent("Assets")
        let directory = assets.appendingPathComponent("Effects")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let graph = EditorShaderGraphTemplates.basic(target: .sprite)
        try JSONEncoder().encode(graph).write(to: directory.appendingPathComponent("Tint.shadergraph"))
        var scene = EditorSceneModel.default(projectName: "Graph scene")
        scene.entities[0].components[EditorBuiltInComponentType.sprite] = [
            "graphMaterial": .object(["path": .string("@res://Effects/Tint.shadergraph")])
        ]
        let world = World()
        let result = EditorSceneFileLoader.load(
            model: scene,
            into: world,
            sourceURL: assets.appendingPathComponent("Scenes/Main.ascn"),
            resourceRootURL: assets
        )
        #expect(result.warnings.isEmpty, Comment(rawValue: result.warnings.joined(separator: "\n")))
        let sprite = try #require(world.getEntityByName("Root")?.components[Sprite.self])
        #expect(sprite.graphMaterial?.descriptor.path == "@res://Effects/Tint.shadergraph")
        #expect(sprite.graphMaterial?.makeInstance().descriptor.path == "@res://Effects/Tint.shadergraph")
        #expect(ShaderGraphResourceScope.rootPath == nil)
    }
}
