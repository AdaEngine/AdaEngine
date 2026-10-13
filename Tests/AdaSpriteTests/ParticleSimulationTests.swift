@testable import AdaSprite
import AdaUtils
import Foundation
import Math
import Testing

@Suite("Particle simulation")
struct ParticleSimulationTests {
    @Test("A bounded burst drains after emission stops")
    func burstAndDrain() throws {
        var emitter = ParticleEmitterDescriptor()
        emitter.burstCount = 10
        emitter.maxParticles = 10
        emitter.emissionRate = 10_000
        emitter.lifetimeMin = 0.1
        emitter.lifetimeMax = 0.1
        var simulation = try ParticleSimulation(.init(emitters: [emitter]))
        simulation.advance(by: 1.0 / 60)
        #expect(simulation.particleCount == 10)
        simulation.advance(by: 0.2, emitting: false)
        #expect(simulation.particleCount == 0)
    }

    @Test("Fixed stepping is deterministic across frame rates")
    func deterministicStepping() throws {
        var emitter = ParticleEmitterDescriptor()
        emitter.shape = .circle
        emitter.lifetimeMin = 2
        emitter.lifetimeMax = 3
        let descriptor = ParticleEffectDescriptor(emitters: [emitter], seed: 72)
        var slow = try ParticleSimulation(descriptor)
        var fast = try ParticleSimulation(descriptor)
        for _ in 0..<30 { slow.advance(by: 1.0 / 30) }
        for _ in 0..<120 { fast.advance(by: 1.0 / 120) }
        #expect(slow.particleCount == fast.particleCount)
        let left = samples(slow)
        let right = samples(fast)
        #expect(left.count == right.count)
        #expect(zip(left, right).allSatisfy { $0.transform == $1.transform && $0.color == $1.color && $0.size == $1.size })
    }

    @Test("World particles remain in place while local particles follow their owner")
    func emissionSpaces() throws {
        for space in ParticleEmitterDescriptor.Space.allCases {
            var emitter = ParticleEmitterDescriptor()
            emitter.space = space
            emitter.burstCount = 1
            emitter.emissionRate = 0
            emitter.speedMin = 0
            emitter.speedMax = 0
            emitter.gravity = .zero
            var simulation = try ParticleSimulation(.init(emitters: [emitter]))
            simulation.advance(by: 1.0 / 120, transform: .init(translation: [10, 20, 0]))
            let particle = try #require(samples(simulation, transform: .init(translation: [100, 200, 0])).first)
            #expect(particle.transform.w.x == (space == .local ? 100 : 10))
            #expect(particle.transform.w.y == (space == .local ? 200 : 20))
        }
    }

    @Test("One-shot duration ends emission and loops replay bursts")
    func durationAndLoops() throws {
        var emitter = ParticleEmitterDescriptor()
        emitter.burstCount = 3
        emitter.emissionRate = 0
        emitter.duration = 0.125
        emitter.lifetimeMin = 2
        emitter.lifetimeMax = 2
        emitter.loops = false
        var single = try ParticleSimulation(.init(emitters: [emitter]))
        single.advance(by: 0.25)
        #expect(single.particleCount == 3)
        emitter.loops = true
        var loop = try ParticleSimulation(.init(emitters: [emitter]))
        loop.advance(by: 0.25)
        #expect(loop.particleCount >= 6)
    }

    @Test("Invalid descriptors and nonfinite time cannot poison simulation")
    func rejectsInvalidInput() throws {
        var emitter = ParticleEmitterDescriptor()
        emitter.maxParticles = Int.max
        #expect(throws: ParticleEffectError.self) { try ParticleSimulation(.init(emitters: [emitter])) }
        emitter = .init()
        emitter.speedMax = .nan
        #expect(throws: ParticleEffectError.self) { try emitter.validate() }
        let bad = Data("{\"emitters\":[{\"lifetimeMin\":-1}]}".utf8)
        #expect(throws: ParticleEffectError.self) { try JSONDecoder().decode(ParticleEffectDescriptor.self, from: bad) }
        var simulation = try ParticleSimulation(.init())
        simulation.advance(by: .nan)
        simulation.advance(by: .infinity)
        simulation.advance(by: -1)
        #expect(simulation.particleCount == 0)
    }

    @Test("Curves interpolate and portable resources round trip")
    func curvesAndCoding() throws {
        let curve = ParticleCurve(keys: [.init(time: 0, value: 2), .init(time: 0.5, value: 1), .init(time: 1, value: 0)])
        #expect(curve.value(at: 0.25) == 1.5)
        #expect(curve.value(at: 0.75) == 0.5)
        #expect(curve.value(at: -1) == 2)
        #expect(curve.value(at: 2) == 0)
        let descriptor = try JSONDecoder().decode(ParticleEffectDescriptor.self, from: Data("{\"emitters\":[{\"name\":\"Flame\"}]}".utf8))
        #expect(descriptor.emitters[0].emissionRate == 80)
        let vectors = try JSONDecoder().decode(ParticleEffectDescriptor.self, from: Data("{\"emitters\":[{\"gravity\":[0,-80],\"boxSize\":[10,20],\"offset\":{\"x\":3,\"y\":4}}]}".utf8))
        #expect(vectors.emitters[0].gravity == Vector2(0, -80))
        #expect(vectors.emitters[0].boxSize == Vector2(10, 20))
        #expect(vectors.emitters[0].offset == Vector2(3, 4))
        #expect(try JSONDecoder().decode(ParticleEffectDescriptor.self, from: JSONEncoder().encode(descriptor)) == descriptor)
        #expect(throws: ParticleEffectError.self) {
            try ParticleCurve(keys: [.init(time: 0.5, value: 1), .init(time: 0.5, value: 0)]).validate()
        }
    }

    private func samples(_ simulation: ParticleSimulation, transform: Transform3D = .identity) -> [ParticleSample] {
        var samples: [ParticleSample] = []
        simulation.forEachParticle(transform: transform) { samples.append($0) }
        return samples
    }
}
