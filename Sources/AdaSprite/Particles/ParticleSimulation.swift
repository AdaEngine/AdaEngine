import AdaUtils
import Math

/// A render sample produced by the same simulation used in the editor and game.
public struct ParticleSample: Sendable {
    public let emitterIndex: Int
    public let transform: Transform3D
    public let size: Float
    public let color: Color
}

/// Deterministic CPU simulation with bounded, instance-owned particle buffers.
public struct ParticleSimulation: Sendable {
    public let descriptor: ParticleEffectDescriptor
    private var states: [EmitterState]
    private var remainder: Double = 0
    private static let step: Double = 1.0 / 120

    private struct Particle: Sendable {
        var age: Float = 0
        var lifetime: Float
        var position: Vector3
        var velocity: Vector3
        var basis: Transform3D
        var size: Float
    }

    private struct EmitterState: Sendable {
        var elapsed: Double = 0
        var emissionRemainder: Double = 0
        var hasStarted = false
        var particles: [Particle] = []
        var randomState: UInt64

        mutating func random() -> Float {
            randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
            return Float(randomState >> 40) / Float(1 << 24)
        }
    }

    public init(_ descriptor: ParticleEffectDescriptor) throws {
        try descriptor.validate()
        self.descriptor = descriptor
        states = descriptor.emitters.enumerated().map { index, emitter in
            var state = EmitterState(randomState: descriptor.seed &+ UInt64(index) &* 7919)
            state.particles.reserveCapacity(emitter.maxParticles)
            return state
        }
    }

    public var particleCount: Int { states.reduce(0) { $0 + $1.particles.count } }

    /// Advances at 120 Hz. A hitch consumes at most 0.25 seconds to bound work per frame.
    /// Stopping emission lets live particles finish; callers pause by not advancing.
    public mutating func advance(by deltaTime: Double, transform: Transform3D = .identity, emitting: Bool = true) {
        guard deltaTime.isFinite, deltaTime > 0 else { return }
        remainder += min(deltaTime, 0.25)
        while remainder + 1e-10 >= Self.step {
            for index in states.indices {
                Self.advance(&states[index], settings: descriptor.emitters[index], transform: transform, emitting: emitting)
            }
            remainder = max(0, remainder - Self.step)
        }
    }

    /// Iterates without constructing a separate array or an ECS entity per particle.
    public func forEachParticle(transform: Transform3D = .identity, _ body: (ParticleSample) -> Void) {
        for index in states.indices {
            let settings = descriptor.emitters[index]
            for particle in states[index].particles {
                let progress = min(1, particle.age / particle.lifetime)
                let color = settings.startColor.asVector + (settings.endColor.asVector - settings.startColor.asVector) * progress
                let rotation = Quat(axis: [0, 0, 1], angle: settings.angularVelocity * .pi / 180 * particle.age)
                let local = Transform3D(translation: particle.position, rotation: .identity, scale: [1, 1, 1])
                    * particle.basis * Transform3D(translation: .zero, rotation: rotation, scale: [1, 1, 1])
                body(ParticleSample(
                    emitterIndex: index,
                    transform: settings.space == .local ? transform * local : local,
                    size: particle.size * settings.sizeCurve.value(at: progress),
                    color: Color(color).opacity(color.w * settings.opacityCurve.value(at: progress))
                ))
            }
        }
    }

    private static func advance(_ state: inout EmitterState, settings: ParticleEmitterDescriptor, transform: Transform3D, emitting: Bool) {
        let delta = Float(step)
        var index = 0
        while index < state.particles.count {
            state.particles[index].age += delta
            if state.particles[index].age >= state.particles[index].lifetime {
                state.particles.swapAt(index, state.particles.count - 1)
                state.particles.removeLast()
                continue
            }
            state.particles[index].position += state.particles[index].velocity * delta + Vector3(settings.gravity, 0) * (0.5 * delta * delta)
            state.particles[index].velocity += Vector3(settings.gravity, 0) * delta
            index += 1
        }
        guard emitting else { return }
        let remaining = max(0, Double(settings.duration) - state.elapsed)
        let interval = settings.loops ? step : min(step, remaining)
        guard interval > 0 else { return }
        var requested = 0
        if !state.hasStarted {
            requested = settings.burstCount
            state.hasStarted = true
        }
        state.elapsed += step
        state.emissionRemainder += Double(settings.emissionRate) * interval
        let continuous = Int(state.emissionRemainder)
        state.emissionRemainder -= Double(continuous)
        requested += continuous
        let count = min(requested, max(0, settings.maxParticles - state.particles.count))
        for _ in 0..<count {
            spawn(&state, settings: settings, transform: transform)
        }
        if settings.loops, state.elapsed >= Double(settings.duration) {
            state.elapsed.formTruncatingRemainder(dividingBy: Double(settings.duration))
            state.hasStarted = false
        }
    }

    private static func spawn(_ state: inout EmitterState, settings: ParticleEmitterDescriptor, transform: Transform3D) {
        var offset = settings.offset
        switch settings.shape {
        case .point: break
        case .box:
            offset += Vector2(state.random() - 0.5, state.random() - 0.5) * settings.boxSize
        case .circle:
            let angle = state.random() * 2 * Float.pi
            let radius = sqrt(state.random()) * settings.radius
            offset += Vector2(cos(angle), sin(angle)) * radius
        }
        let angle = (settings.direction + (state.random() - 0.5) * settings.spread) * .pi / 180
        let speed = settings.speedMin + (settings.speedMax - settings.speedMin) * state.random()
        var position = Vector3(offset, 0)
        var velocity = Vector3(cos(angle) * speed, sin(angle) * speed, 0)
        var basis = Transform3D.identity
        if settings.space == .world {
            let transformedPosition = transform * Vector4(position, 1)
            let transformedVelocity = transform * Vector4(velocity, 0)
            position = Vector3(transformedPosition.x, transformedPosition.y, transformedPosition.z)
            velocity = Vector3(transformedVelocity.x, transformedVelocity.y, transformedVelocity.z)
            basis = transform
            basis.w = [0, 0, 0, 1]
        }
        let lifetime = settings.lifetimeMin + (settings.lifetimeMax - settings.lifetimeMin) * state.random()
        let size = settings.sizeMin + (settings.sizeMax - settings.sizeMin) * state.random()
        state.particles.append(Particle(lifetime: lifetime, position: position, velocity: velocity, basis: basis, size: size))
    }
}
