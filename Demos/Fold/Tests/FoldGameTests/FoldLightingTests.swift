import AdaEngine
@_spi(Internal) import AdaRender
@testable import AdaSprite
@testable import FoldGame
import Foundation
import Testing

@MainActor @Suite(.serialized)
struct FoldLightingTests {
    @Test func lightsAndOccludersFollowFoldWithoutRespawning() throws {
        if unsafe RenderEngine.shared == nil { unsafe RenderEngine.configurations.preferredBackend = .headless }
        let world = World(name: "Fold lighting tests")
        RenderWorldPlugin().setup(in: AppWorlds(main: world))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let level = try JSONDecoder().decode(ShadowLevelDefinition.self, from: Data(contentsOf: root.appendingPathComponent("Assets/Levels/intro.json")))
        var game = ShadowSimulation(level: level)
        let lighting = FoldLightingScene()
        lighting.update(world: world, game: game, size: Size(width: 1024, height: 650))
        let ids = Set(world.getEntities().map(\.id))
        let light = try #require(world.getEntities().first { $0.components[Light2D.self] != nil })
        #expect(light.components[Light2D.self]?.castsShadows == true)
        let first = try #require(light.components[Transform.self]?.position)
        let prism = try #require(world.getEntities().first { $0.name == "Fold Lighting / Prism0" })
        let before = try #require(prism.components[LightOccluder2D.self]?.points)
        game.advance(input: ShadowPlayerInput(), angle: 135, deltaTime: 1 / 60)
        lighting.update(world: world, game: game, size: Size(width: 1024, height: 650))
        #expect(Set(world.getEntities().map(\.id)) == ids)
        #expect(light.components[Transform.self]?.position != first)
        #expect(prism.components[LightOccluder2D.self]?.points != before)
        for paper in world.getEntities() where paper.components[Mesh2D.self] != nil {
            #expect(paper.components[BoundingComponent.self] != nil)
            let mesh = try #require(paper.components[Mesh2D.self])
            let part = try #require(mesh.mesh.models.first?.parts.first)
            let material = try #require(mesh.materials.first)
            let device = try #require(world.getResource(RenderDeviceHandler.self)?.renderDevice)
            #expect(material.getOrCreatePipeline(for: part.vertexDescriptor, keys: [], device: device) != nil)
            let uploaded = try #require(material.getValue(for: "ColorCanvasMaterial", type: Color.self))
            #expect(uploaded.alpha == 1 && uploaded.red > 0.8)

        }
        let meshes = world.getEntities().compactMap { $0.components[Mesh2D.self]?.mesh }
        lighting.update(world: world, game: game, size: Size(width: 1024, height: 650))
        let retained = world.getEntities().compactMap { $0.components[Mesh2D.self]?.mesh }
        #expect(meshes.count == 2 && retained.count == 2)
        #expect(FoldLightingScene.worldPoint(Vector2(512, 325), size: Size(width: 1024, height: 650)) == .zero)
    }
}
