@testable import AdaApp
import AdaAssets
import AdaECS
@_spi(Internal) @testable import AdaRender
import AdaScripting
import AdaSprite
import Foundation
import Math
import Testing

@MainActor
@Suite("AdaScript sprite animation", .serialized)
struct AdaScriptSpriteAnimationTests {
    private func writeSet(into root: URL) throws -> URL {
        var image = Image(width: 4, height: 2, color: .white)
        image.setPixel(in: [0, 0], color: .red)
        try image.writePNG(to: root.appendingPathComponent("sheet.png"))
        let url = root.appendingPathComponent("hero.spriteanim")
        try """
        image: sheet.png
        cellSize: {width: 2, height: 2}
        filter: nearest
        clips:
          - {name: idle, framesPerSecond: 10, frames: [{atlasCoordinates: {x: 0, y: 0}}, {atlasCoordinates: {x: 1, y: 0}}]}
          - {name: jump, framesPerSecond: 10, playbackMode: once, frames: [{atlasCoordinates: {x: 1, y: 0}}]}
        """.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("A script builds an animator from a .spriteanim path, then drives it through its fields")
    func constructAndControl() async throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AdaSpriteAnimScript-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = try writeSet(into: root)
        AssetsManager.registerAssetType(SpriteAnimationSet.self)
        RuntimeTypeRegistry.registerComponent(SpriteAnimator.self, names: ["SpriteAnimator"])
        RuntimeTypeRegistry.registerComponent(Sprite.self, names: ["Sprite"], makeDefault: { Sprite(texture: Texture2D.whiteTexture) })

        let spawn = try AdaScriptPlugin(source: """
            @system class SpawnHero {
                func update(context) {
                    var set: SpriteAnimationSet = Assets.preload("\(url.path)");
                    context.world.spawn([Sprite(), SpriteAnimator(animations: set, initialClip: "idle", speed: 1.5)]);
                }
            }
            """)
        let spawnWorld = World()
        spawn.setup(in: AppWorlds(main: spawnWorld))
        await spawnWorld.runScheduler(.update)
        #expect(spawn.diagnostics.isEmpty, Comment(rawValue: spawn.diagnostics.joined(separator: "\n")))
        let built = try #require(spawnWorld.getEntities().compactMap { $0.components[SpriteAnimator.self] }.first)
        #expect(built.animations?.asset?.clips.map(\.name) == ["idle", "jump"])
        #expect(built.currentClip == "idle")
        #expect(built.speed == 1.5)

        let controls = try AdaScriptPlugin(source: """
            @system class ControlHero {
                @query(SpriteAnimator) var heroes;
                func update(context) {
                    for (var entity in heroes) {
                        entity.spriteAnimator.currentClip = "jump";
                        entity.spriteAnimator.isPlaying = false;
                        entity.spriteAnimator.speed = 2;
                        entity.spriteAnimator.restartCount = 4;
                    }
                }
            }
            """)
        let controlWorld = World()
        let entity = controlWorld.spawn { built }
        controls.setup(in: AppWorlds(main: controlWorld))
        await controlWorld.runScheduler(.update)
        #expect(controls.diagnostics.isEmpty, Comment(rawValue: controls.diagnostics.joined(separator: "\n")))
        let controlled = try #require(entity.components[SpriteAnimator.self])
        #expect(controlled.currentClip == "jump")
        #expect(!controlled.isPlaying)
        #expect(controlled.speed == 2)
        #expect(controlled.restartCount == 4)
    }
}
