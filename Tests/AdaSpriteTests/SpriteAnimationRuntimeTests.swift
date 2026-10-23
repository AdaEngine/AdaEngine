import AdaAssets
import AdaECS
@_spi(Internal) @testable import AdaRender
@testable import AdaSprite
import AdaTransform
import AdaUtils
import Foundation
import Math
import Testing

/// Runs the real system in a real world with real textures, instead of poking the state machine.
@MainActor
@Suite("Sprite animation runtime", .serialized)
struct SpriteAnimationRuntimeTests {
    init() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
    }
    private let cell = 2

    /// Four 2x2 cells in one row: red, green, blue, yellow.
    private func sheetImage() -> Image {
        var image = Image(width: cell * 4, height: cell, color: .black)
        let colors: [Color] = [.red, .green, .blue, .yellow]
        for (index, color) in colors.enumerated() {
            for y in 0..<cell {
                for x in 0..<cell { image.setPixel(in: [Float(index * cell + x), Float(y)], color: color) }
            }
        }
        return image
    }

    private func makeSet(clips: [SpriteAnimationClip]) throws -> SpriteAnimationSet {
        try SpriteAnimationSet(
            descriptor: SpriteAnimationSetDescriptor(image: "sheet.png", cellSize: SizeInt(width: cell, height: cell), filter: .nearest, clips: clips),
            image: sheetImage()
        )
    }

    private func makeWorld() throws -> World {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        Transform.registerComponent()
        GlobalTransform.registerComponent()
        Visibility.registerComponent()
        BoundingComponent.registerComponent()
        Sprite.registerComponent()
        SpriteAnimator.registerComponent()
        let world = World()
        world.insertResource(HandledEvents())
        world.addSystem(SpriteAnimationSystem.self, on: .update)
        return world
    }

    private func tick(_ world: World, _ delta: Float) async -> [SpriteAnimationEvent] {
        if world.getResource(EventsStorage<SpriteAnimationEvent>.self) != nil {
            world.getRefResource(EventsStorage<SpriteAnimationEvent>.self).wrappedValue.swapAndDropOld()
        }
        // The scheduler owns DeltaTime; an explicit step keeps the test off wall-clock time.
        await world.runScheduler(.update, deltaTime: TimeInterval(delta))
        let receiver = Events<SpriteAnimationEvent>()
        receiver.update(from: world)
        return Array(receiver.currentEvents)
    }

    private func slice(of entity: Entity) -> TextureAtlas.Slice? {
        entity.components[Sprite.self]?.texture?.asset as? TextureAtlas.Slice
    }

    @Test("The sprite shows each frame as time passes, wraps, and shares slices between entities")
    func playsFrames() async throws {
        let set = try makeSet(clips: [.row("run", row: 0, columns: 0..<4, framesPerSecond: 10)])
        let world = try makeWorld()
        let first = world.spawn { Sprite(); SpriteAnimator(animations: AssetHandle(set)) }
        let second = world.spawn { Sprite(); SpriteAnimator(animations: AssetHandle(set), speed: 2) }

        // The first update already shows frame 0, before any time passes.
        _ = await tick(world, 0)
        #expect(slice(of: first)?.position == Vector2(0, 0))
        #expect(slice(of: first) === slice(of: second))

        _ = await tick(world, 0.1)
        #expect(slice(of: first)?.position == Vector2(2, 0))
        #expect(slice(of: second)?.position == Vector2(4, 0)) // twice as fast
        #expect(slice(of: first)?.size == SizeInt(width: 2, height: 2))

        for _ in 0..<3 { _ = await tick(world, 0.1) }
        #expect(slice(of: first)?.position == Vector2(0, 0)) // 0.4 s of a four-frame, 10 fps loop
    }

    @Test("Events arrive in order with their clip and entity")
    func events() async throws {
        let clip = SpriteAnimationClip(
            name: "attack",
            frames: [
                SpriteAnimationFrame(atlasCoordinates: [0, 0]),
                SpriteAnimationFrame(atlasCoordinates: [1, 0], marker: "hit"),
                SpriteAnimationFrame(atlasCoordinates: [2, 0])
            ],
            framesPerSecond: 10,
            playbackMode: .once
        )
        let world = try makeWorld()
        let set = try makeSet(clips: [clip])
        let entity = world.spawn { Sprite(); SpriteAnimator(animations: AssetHandle(set)) }

        #expect(await tick(world, 0.1).map(\.kind) == [.frameChanged(1), .marker("hit")])
        let finishing = await tick(world, 0.1)
        #expect(finishing.map(\.kind) == [.frameChanged(2)])
        let last = await tick(world, 0.1)
        #expect(last.map(\.kind) == [.finished])
        #expect(last.allSatisfy { $0.clip == "attack" && $0.entityID == entity.id })
        #expect(await tick(world, 1).isEmpty)
        #expect(slice(of: entity)?.position == Vector2(4, 0)) // holds the final frame
    }

    @Test("Writing the component's fields, as a script or inspector does, switches, pauses and restarts")
    func fieldControls() async throws {
        let set = try makeSet(clips: [
            .row("idle", row: 0, columns: 0..<2, framesPerSecond: 10),
            .row("jump", row: 0, columns: 2..<4, framesPerSecond: 10)
        ])
        let world = try makeWorld()
        let entity = world.spawn { Sprite(); SpriteAnimator(animations: AssetHandle(set)) }
        #expect(entity.components[SpriteAnimator.self]?.currentClip == "idle") // defaults to the first clip

        _ = await tick(world, 0.1)
        #expect(slice(of: entity)?.position == Vector2(2, 0))

        entity.components[SpriteAnimator.self]?.currentClip = "jump"
        _ = await tick(world, 0)
        #expect(slice(of: entity)?.position == Vector2(4, 0))

        entity.components[SpriteAnimator.self]?.isPlaying = false
        _ = await tick(world, 1)
        #expect(slice(of: entity)?.position == Vector2(4, 0))

        entity.components[SpriteAnimator.self]?.isPlaying = true
        _ = await tick(world, 0.1)
        #expect(slice(of: entity)?.position == Vector2(6, 0))

        entity.components[SpriteAnimator.self]?.restartCount += 1
        _ = await tick(world, 0)
        #expect(slice(of: entity)?.position == Vector2(4, 0))
    }

    @Test("Pixel regions select exactly the authored rectangle")
    func regionFrames() async throws {
        let clip = SpriteAnimationClip(
            name: "odd",
            frames: [SpriteAnimationFrame(region: RectInt(x: 3, y: 1, width: 4, height: 1))],
            framesPerSecond: 1
        )
        let world = try makeWorld()
        let set = try makeSet(clips: [clip])
        let entity = world.spawn { Sprite(); SpriteAnimator(animations: AssetHandle(set)) }
        _ = await tick(world, 0)
        #expect(slice(of: entity)?.position == Vector2(3, 1))
        #expect(slice(of: entity)?.size == SizeInt(width: 4, height: 1))
    }

    @Test("Unknown clips, missing sets and frames outside the image leave the sprite alone")
    func inertCases() async throws {
        let outside = SpriteAnimationClip(
            name: "outside",
            frames: [SpriteAnimationFrame(region: RectInt(x: 100, y: 100, width: 4, height: 4))],
            framesPerSecond: 1
        )
        let set = try makeSet(clips: [outside, .row("ok", row: 0, columns: 0..<1)])
        let world = try makeWorld()
        let sentinel = Texture2D.whiteTexture
        let unknown = world.spawn { Sprite(texture: sentinel); SpriteAnimator(animations: AssetHandle(set), initialClip: "missing") }
        let noSet = world.spawn { Sprite(texture: sentinel); SpriteAnimator(initialClip: "ok") }
        let off = world.spawn { Sprite(texture: sentinel); SpriteAnimator(animations: AssetHandle(set), initialClip: "outside") }
        for _ in 0..<3 { _ = await tick(world, 0.5) }
        for entity in [unknown, noSet, off] {
            #expect(entity.components[Sprite.self]?.texture?.asset === sentinel)
        }
    }

    @Test("A .spriteanim file loads through the asset manager, resolving the image next to it")
    func loadsFromDisk() async throws {
        _ = try makeWorld()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SpriteAnimation-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Art"), withIntermediateDirectories: true)
        try sheetImage().writePNG(to: root.appendingPathComponent("Art/sheet.png"))
        let url = root.appendingPathComponent("Art/hero.spriteanim")
        try """
        version: 1
        image: sheet.png
        cellSize: {width: 2, height: 2}
        filter: nearest
        clips:
          - name: run
            framesPerSecond: 8
            playbackMode: loop
            frames:
              - {atlasCoordinates: {x: 0, y: 0}}
              - {atlasCoordinates: {x: 1, y: 0}, duration: 2, marker: step}
        """.write(to: url, atomically: true, encoding: .utf8)

        AssetsManager.registerAssetType(SpriteAnimationSet.self)
        let set = try #require(try await AssetsManager.load(SpriteAnimationSet.self, at: url.path).asset)
        #expect(set.clips.map(\.name) == ["run"])
        #expect(set.clips[0].frames[1].marker == "step")
        #expect(set.clips[0].framesPerSecond == 8)
        #expect(set.atlas.width == 8 && set.atlas.height == 2)
        let texture = try #require(set.texture(for: set.clips[0].frames[1]) as? TextureAtlas.Slice)
        #expect(texture.position == Vector2(2, 0))
    }

    @Test("A resource that points at a missing image or has bad clips fails to load instead of half-loading")
    func rejectsBadResources() async throws {
        _ = try makeWorld()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SpriteAnimationBad-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        AssetsManager.registerAssetType(SpriteAnimationSet.self)

        let missingImage = root.appendingPathComponent("missing.spriteanim")
        try "image: nowhere.png\nclips: []\n".write(to: missingImage, atomically: true, encoding: .utf8)
        let duplicate = root.appendingPathComponent("duplicate.spriteanim")
        try sheetImage().writePNG(to: root.appendingPathComponent("sheet.png"))
        try """
        image: sheet.png
        clips:
          - {name: a, frames: [{atlasCoordinates: {x: 0, y: 0}}]}
          - {name: a, frames: [{atlasCoordinates: {x: 0, y: 0}}]}
        """.write(to: duplicate, atomically: true, encoding: .utf8)

        for url in [missingImage, duplicate] {
            await #expect(throws: (any Error).self) { try await AssetsManager.load(SpriteAnimationSet.self, at: url.path) }
        }
    }
}
