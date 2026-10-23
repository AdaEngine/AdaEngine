import AdaAssets
import AdaECS
@testable import AdaSprite
import AdaTransform
import Testing

@MainActor
@Suite("Particle runtime")
struct ParticleRuntimeTests {
    @Test("Instances keep independent buffers and restart through reflected controls")
    func instancesAndRestart() async throws {
        ParticleEmitter.registerComponent()
        Transform.registerComponent()
        var descriptor = ParticleEmitterDescriptor()
        descriptor.burstCount = 8
        descriptor.emissionRate = 0
        descriptor.loops = false
        let effect = AssetHandle(try ParticleEffect(.init(emitters: [descriptor])))
        let world = World()
        world.insertResource(DeltaTime(deltaTime: 1.0 / 60))
        world.addSystem(TransformSystem.self, on: .postUpdate)
        world.addSystem(ChildTransformSystem.self, on: .postUpdate)
        world.addSystem(ParticleSimulationSystem.self, on: .postUpdate)
        let first = world.spawn { Transform(); ParticleEmitter(effect: effect) }
        let second = world.spawn { Transform(); ParticleEmitter(effect: effect, isPaused: true) }
        await world.runScheduler(.postUpdate, deltaTime: 1.0 / 60)
        #expect(first.components[ParticleEmitter.self]?.particleCount == 8)
        #expect(second.components[ParticleEmitter.self]?.particleCount == 0)
        first.components[ParticleEmitter.self]?.isPaused = true
        second.components[ParticleEmitter.self]?.isPaused = false
        await world.runScheduler(.postUpdate, deltaTime: 1.0 / 60)
        #expect(first.components[ParticleEmitter.self]?.particleCount == 8)
        #expect(second.components[ParticleEmitter.self]?.particleCount == 8)
        first.components[ParticleEmitter.self]?.restartCount = 1
        await world.runScheduler(.postUpdate, deltaTime: 1.0 / 60)
        #expect(first.components[ParticleEmitter.self]?.particleCount == 0)
        first.components[ParticleEmitter.self]?.isPaused = false
        await world.runScheduler(.postUpdate, deltaTime: 1.0 / 60)
        #expect(first.components[ParticleEmitter.self]?.particleCount == 8)
    }
}
