@testable import AdaApp
import AdaAssets
import AdaECS
import AdaScripting
import AdaSprite
import Foundation
import Testing

@MainActor
@Suite("AdaScript particles", .serialized)
struct AdaScriptParticleTests {
    @Test("Particle resources reach the real VM constructor and query controls")
    func resourceAndControls() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AdaParticlesScript-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("Burst.particles")
        try "emitters:\n  - name: Burst\n    loops: false\n    emissionRate: 0\n    burstCount: 10\n".write(to: url, atomically: true, encoding: .utf8)
        AssetsManager.registerAssetType(ParticleEffect.self)
        RuntimeTypeRegistry.registerComponent(ParticleEmitter.self, names: ["ParticleEmitter"])
        let plugin = try AdaScriptPlugin(source: """
            @system class SpawnParticles {
                func update(context) {
                    var effect: ParticleEffect = Assets.preload("\(url.path)");
                    context.world.spawn([ParticleEmitter(effect: effect)]);
                }
            }
            """)
        let world = World()
        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)
        #expect(plugin.diagnostics.isEmpty, Comment(rawValue: plugin.diagnostics.joined(separator: "\n")))
        let emitter = try #require(world.getEntities().compactMap { $0.components[ParticleEmitter.self] }.first)
        #expect(emitter.effect?.asset?.descriptor.emitters.first?.name == "Burst")
        let controls = try AdaScriptPlugin(source: """
            @system class ControlParticles {
                @query(ParticleEmitter) var effects;
                func update(context) {
                    for (var entity in effects) {
                        entity.particleEmitter.isEmitting = false;
                        entity.particleEmitter.isPaused = true;
                        entity.particleEmitter.restartCount = 2;
                    }
                }
            }
            """)
        let controlWorld = World()
        let entity = controlWorld.spawn { emitter }
        controls.setup(in: AppWorlds(main: controlWorld))
        await controlWorld.runScheduler(.update)
        #expect(controls.diagnostics.isEmpty, Comment(rawValue: controls.diagnostics.joined(separator: "\n")))
        let controlled = try #require(entity.components[ParticleEmitter.self])
        #expect(!controlled.isEmitting)
        #expect(controlled.isPaused)
        #expect(controlled.restartCount == 2)
    }
}
