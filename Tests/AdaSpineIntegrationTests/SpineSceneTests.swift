import AdaAssets
import AdaCorePipelines
import AdaECS
@testable import AdaRender
@testable import AdaSpine
@testable import AdaTransform
import AdaUtils
import Foundation
import Math
import Testing

@MainActor
@Suite("Spine scene integration", .serialized)
struct SpineSceneTests {
    @Test func portableSourceCreatesIndependentPlayersAndPreservesSettings() throws {
        try setupRenderer()
        let source = SpineSource(source: "@res://hero.spine", animation: "move", autoplay: false, speed: 2, showBones: true)
        #expect(try JSONDecoder().decode(SpineSource.self, from: JSONEncoder().encode(source)) == source)
        let world = World()
        let first = world.spawn { Transform() }
        let second = world.spawn { Transform() }
        try source.instantiate(makeSkeleton(), on: first)
        try source.instantiate(makeSkeleton(), on: second)
        let a = try #require(first.components[SpineAnimation.self])
        let b = try #require(second.components[SpineAnimation.self])
        #expect(a.isPaused && a.speed == 2)
        #expect(first.components[SpineDebugBones.self] != nil)
        #expect(first.components[SpineSourceState.self]?.reference == source)
        a.player.advance(by: 0.5)
        #expect(a.player.time == 0.5 && b.player.time == 0)
        var invalid = source
        invalid.animation = "missing"
        #expect(throws: SpineError.self) { try invalid.instantiate(makeSkeleton(), on: first) }
        #expect(first.components[SpineAnimation.self]?.player === a.player)
    }

    @Test func playbackSystemRespectsPauseAndSpeed() async throws {
        try setupRenderer()
        let world = World()
        world.addSchedulers(.update)
        world.addSystem(SpineAnimationSystem.self, on: .update)
        let animation = try SpineAnimation(skeleton: makeSkeleton())
        try animation.player.play("move", transitionDuration: 0)
        let entity = world.spawn { animation; Transform() }
        await world.runScheduler(.update, deltaTime: 0.25)
        #expect(animation.player.time == 0.25)
        #expect(entity.components[NoFrustumCulling.self] != nil)
        var component = try #require(entity.components[SpineAnimation.self])
        component.speed = 2
        entity.components[SpineAnimation.self] = component
        await world.runScheduler(.update, deltaTime: 0.25)
        #expect(animation.player.time == 0.75)
        component.isPaused = true
        entity.components[SpineAnimation.self] = component
        await world.runScheduler(.update, deltaTime: 0.25)
        #expect(animation.player.time == 0.75)
    }

    @Test func extractsAndPreparesCharacterGeometryWithOwnerVisibilityAndTransform() async throws {
        try setupRenderer()
        Camera.registerComponent()
        VisibleEntities.registerComponent()
        let main = World()
        let animation = try SpineAnimation(skeleton: makeSkeleton())
        try animation.player.play("move", transitionDuration: 0)
        animation.player.advance(by: 0.5)
        let owner = main.spawn {
            animation
            Transform()
            GlobalTransform(matrix: Transform3D(translation: [3, 4, 5]))
        }
        let render = World()
        render.addSchedulers(.extract, .preUpdate)
        render
            .insertResource(MainWorld(world: main))
            .insertResource(ExtractedSpineDraws())
            .insertResource(SpineRenderData())
            .insertResource(RenderItems<Transparent2DRenderItem>())
            .insertResource(RenderDeviceHandler(renderDevice: unsafe RenderEngine.shared.renderDevice))
            .addSystem(ExtractSpineSystem.self, on: .extract)
            .addSystem(PrepareSpineSystem.self, on: .preUpdate)
        render.spawn { Camera(); VisibleEntities(entityIds: [owner.id]) }
        // Shared render items must not duplicate a character seen by two cameras.
        render.spawn { Camera(); VisibleEntities(entityIds: [owner.id]) }
        render.spawn { Camera(); VisibleEntities() }
        await render.runScheduler(.extract)
        await render.runScheduler(.preUpdate)
        let data = try #require(render.getResource(SpineRenderData.self))
        let items = try #require(render.getResource(RenderItems<Transparent2DRenderItem>.self))
        #expect(items.items.count == 1)
        #expect(items.items.first?.sortKey == 5)
        #expect(data.indices.count == 6)
        #expect(data.vertices.count == 4)
        #expect(data.vertices.buffer != nil && data.indices.buffer != nil)
        let centerX = data.vertices.elements.reduce(0) { $0 + $1.position.x } / 4
        #expect(abs(centerX - 13) < 0.001)
        #expect(data.vertices.elements.allSatisfy { $0.position.z == 5 })

        owner.components[SpineDebugBones.self] = SpineDebugBones()
        await render.runScheduler(.extract)
        render.insertResource(RenderItems<Transparent2DRenderItem>())
        await render.runScheduler(.preUpdate)
        let debugData = try #require(render.getResource(SpineRenderData.self))
        #expect(debugData.vertices.count > data.vertices.count)
        #expect(try #require(render.getResource(RenderItems<Transparent2DRenderItem>.self)).items.count == 2)
        #expect(debugData.batches.values.allSatisfy { $0.owner == owner.id })

        owner.components[Visibility.self] = .hidden
        await render.runScheduler(.extract)
        render.insertResource(RenderItems<Transparent2DRenderItem>())
        await render.runScheduler(.preUpdate)
        #expect(try #require(render.getResource(SpineRenderData.self)).indices.isEmpty)
        #expect(try #require(render.getResource(RenderItems<Transparent2DRenderItem>.self)).items.isEmpty)
    }

    @Test(arguments: ["spine", "json"]) func loadsExportAtlasAndPNGFromDisk(fileExtension: String) async throws {
        try setupRenderer()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ada-spine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let skeletonURL = directory.appendingPathComponent("hero.\(fileExtension)")
        try Data(skeletonJSON.utf8).write(to: skeletonURL)
        try Data(atlasText.utf8).write(to: directory.appendingPathComponent("hero.atlas"))
        try Image(width: 16, height: 16, color: .white).writePNG(to: directory.appendingPathComponent("hero.png"))
        let handle = try await AssetsManager.load(SpineSkeleton.self, at: skeletonURL.path)
        #expect(handle.asset.animationNames == ["move"])
        #expect(handle.asset.textures.count == 1)
        #expect(handle.asset.textures[0].asset.width == 16)
        let first = try SpineAnimation(skeleton: handle.asset)
        let second = try SpineAnimation(skeleton: handle.asset)
        try first.player.play("move", transitionDuration: 0)
        first.player.advance(by: 0.5)
        #expect(first.player.time == 0.5)
        #expect(second.player.time == 0)
    }

    private func makeSkeleton() throws -> SpineSkeleton {
        try SpineSkeleton(skeleton: Data(skeletonJSON.utf8), atlas: atlasText,
                          textures: [AssetHandle(Texture2D(image: Image(width: 16, height: 16, color: .white)))])
    }

    private func setupRenderer() throws {
        guard unsafe RenderEngine.shared == nil else { return }
        unsafe RenderEngine.configurations.preferredBackend = .headless
        try RenderEngine.setupRenderEngine()
    }
}

private let atlasText = """
hero.png
size: 16,16
filter: Linear,Linear
body
bounds: 0,0,16,16
"""

private let skeletonJSON = #"""
{
  "skeleton":{"spine":"4.2.00"},
  "bones":[{"name":"root"}],
  "slots":[{"name":"body","bone":"root","attachment":"body"}],
  "skins":[{"name":"default","attachments":{"body":{"body":{"width":16,"height":16}}}}],
  "animations":{"move":{"bones":{"root":{"translatex":[{"value":0},{"time":1,"value":20}]}}}}
}
"""#
