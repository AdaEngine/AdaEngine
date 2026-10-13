import AdaUtils
import Foundation
import Math

/// A piecewise linear curve sampled over a particle's normalized lifetime.
public struct ParticleCurve: Codable, Equatable, Sendable {
    public struct Key: Codable, Equatable, Sendable {
        public var time: Float
        public var value: Float

        public init(time: Float, value: Float) {
            self.time = time
            self.value = value
        }
    }

    public var keys: [Key]

    public init(keys: [Key] = [.init(time: 0, value: 1), .init(time: 1, value: 0)]) {
        self.keys = keys
    }

    public func value(at time: Float) -> Float {
        guard let first = keys.first else { return 1 }
        if time <= first.time { return first.value }
        for index in 1..<keys.count where time <= keys[index].time {
            let left = keys[index - 1]
            let right = keys[index]
            let factor = (time - left.time) / (right.time - left.time)
            return left.value + (right.value - left.value) * factor
        }
        return keys.last?.value ?? 1
    }

    func validate() throws {
        guard (1...32).contains(keys.count) else { throw ParticleEffectError.invalid("A curve needs 1–32 keys.") }
        var previous: Float = -1
        for key in keys {
            guard key.time.isFinite, (0...1).contains(key.time), key.time > previous,
                key.value.isFinite, (0...100).contains(key.value) else {
                throw ParticleEffectError.invalid("Curve keys must have increasing times in 0…1 and values in 0…100.")
            }
            previous = key.time
        }
    }
}

/// Authored settings for one emitter. Angles are in degrees; distances use scene units.
public struct ParticleEmitterDescriptor: Codable, Equatable, Sendable {
    public enum Shape: String, Codable, CaseIterable, Sendable { case point, box, circle }
    public enum Space: String, Codable, CaseIterable, Sendable { case local, world }

    public var name = "Emitter"
    public var shape: Shape = .point
    public var space: Space = .world
    public var offset: Vector2 = .zero
    public var boxSize: Vector2 = [40, 40]
    public var radius: Float = 20
    /// Empty uses a white quad. Nonempty paths load a Texture2D through AdaAssets.
    public var texture = ""
    public var maxParticles = 512
    public var emissionRate: Float = 80
    public var burstCount = 0
    public var duration: Float = 2
    public var loops = true
    public var lifetimeMin: Float = 0.5
    public var lifetimeMax: Float = 1.5
    public var speedMin: Float = 30
    public var speedMax: Float = 80
    public var direction: Float = 90
    public var spread: Float = 45
    /// Acceleration in world axes for world-space particles, emitter axes for local particles.
    public var gravity: Vector2 = [0, -30]
    public var sizeMin: Float = 4
    public var sizeMax: Float = 8
    public var angularVelocity: Float = 0
    public var startColor: Color = .orange
    public var endColor: Color = .yellow.opacity(0)
    public var sizeCurve = ParticleCurve()
    public var opacityCurve = ParticleCurve(keys: [.init(time: 0, value: 1), .init(time: 1, value: 1)])

    public init(name: String = "Emitter") { self.name = name }

    public func validate() throws {
        let numbers = [offset.x, offset.y, boxSize.x, boxSize.y, radius, emissionRate, duration,
                       lifetimeMin, lifetimeMax, speedMin, speedMax, direction, spread, gravity.x, gravity.y,
                       sizeMin, sizeMax, angularVelocity] + [startColor, endColor].flatMap { [$0.red, $0.green, $0.blue, $0.alpha] }
        guard numbers.allSatisfy({ $0.isFinite && abs($0) <= 1_000_000 }),
            (1...4096).contains(maxParticles), (0...maxParticles).contains(burstCount),
            (0...10_000).contains(emissionRate), (0.001...3600).contains(duration),
            lifetimeMin >= 0.001, lifetimeMax >= lifetimeMin, lifetimeMax <= 3600,
            speedMin >= 0, speedMax >= speedMin, sizeMin >= 0, sizeMax >= sizeMin,
            boxSize.x >= 0, boxSize.y >= 0, radius >= 0, (0...360).contains(spread) else {
            throw ParticleEffectError.invalid("Invalid settings for emitter '\(name)'. Check ranges and particle limits.")
        }
        try sizeCurve.validate()
        try opacityCurve.validate()
    }

    private enum CodingKeys: String, CodingKey {
        case name, shape, space, offset, boxSize, radius, texture, maxParticles, emissionRate, burstCount, duration, loops
        case lifetimeMin, lifetimeMax, speedMin, speedMax, direction, spread, gravity, sizeMin, sizeMax, angularVelocity
        case startColor, endColor, sizeCurve, opacityCurve
    }

    public init(from decoder: any Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? name
        shape = try values.decodeIfPresent(Shape.self, forKey: .shape) ?? shape
        space = try values.decodeIfPresent(Space.self, forKey: .space) ?? space
        offset = try Self.decodeVector(values, key: .offset, fallback: offset)
        boxSize = try Self.decodeVector(values, key: .boxSize, fallback: boxSize)
        radius = try values.decodeIfPresent(Float.self, forKey: .radius) ?? radius
        texture = try values.decodeIfPresent(String.self, forKey: .texture) ?? texture
        maxParticles = try values.decodeIfPresent(Int.self, forKey: .maxParticles) ?? maxParticles
        emissionRate = try values.decodeIfPresent(Float.self, forKey: .emissionRate) ?? emissionRate
        burstCount = try values.decodeIfPresent(Int.self, forKey: .burstCount) ?? burstCount
        duration = try values.decodeIfPresent(Float.self, forKey: .duration) ?? duration
        loops = try values.decodeIfPresent(Bool.self, forKey: .loops) ?? loops
        lifetimeMin = try values.decodeIfPresent(Float.self, forKey: .lifetimeMin) ?? lifetimeMin
        lifetimeMax = try values.decodeIfPresent(Float.self, forKey: .lifetimeMax) ?? lifetimeMax
        speedMin = try values.decodeIfPresent(Float.self, forKey: .speedMin) ?? speedMin
        speedMax = try values.decodeIfPresent(Float.self, forKey: .speedMax) ?? speedMax
        direction = try values.decodeIfPresent(Float.self, forKey: .direction) ?? direction
        spread = try values.decodeIfPresent(Float.self, forKey: .spread) ?? spread
        gravity = try Self.decodeVector(values, key: .gravity, fallback: gravity)
        sizeMin = try values.decodeIfPresent(Float.self, forKey: .sizeMin) ?? sizeMin
        sizeMax = try values.decodeIfPresent(Float.self, forKey: .sizeMax) ?? sizeMax
        angularVelocity = try values.decodeIfPresent(Float.self, forKey: .angularVelocity) ?? angularVelocity
        startColor = try values.decodeIfPresent(Color.self, forKey: .startColor) ?? startColor
        endColor = try values.decodeIfPresent(Color.self, forKey: .endColor) ?? endColor
        sizeCurve = try values.decodeIfPresent(ParticleCurve.self, forKey: .sizeCurve) ?? sizeCurve
        opacityCurve = try values.decodeIfPresent(ParticleCurve.self, forKey: .opacityCurve) ?? opacityCurve
        try validate()
    }

    private static func decodeVector(_ values: KeyedDecodingContainer<CodingKeys>, key: CodingKeys, fallback: Vector2) throws -> Vector2 {
        guard values.contains(key), try !values.decodeNil(forKey: key) else { return fallback }
        if let components = try? values.decode([Float].self, forKey: key), components.count == 2 {
            return Vector2(components[0], components[1])
        }
        return try values.decode(Vector2.self, forKey: key)
    }
}

/// Portable contents of a `.particles` resource. Runtime state is owned by each instance.
public struct ParticleEffectDescriptor: Codable, Equatable, Sendable {
    public var version: Int
    public var seed: UInt64
    public var emitters: [ParticleEmitterDescriptor]

    public init(emitters: [ParticleEmitterDescriptor] = [.init()], seed: UInt64 = 1) {
        self.version = 1
        self.seed = seed
        self.emitters = emitters
    }

    public func validate() throws {
        guard version == 1, (1...16).contains(emitters.count) else {
            throw ParticleEffectError.invalid("Particle effects require version 1 and 1–16 emitters.")
        }
        for emitter in emitters { try emitter.validate() }
    }

    private enum CodingKeys: CodingKey { case version, seed, emitters }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        seed = try values.decodeIfPresent(UInt64.self, forKey: .seed) ?? 1
        emitters = try values.decode([ParticleEmitterDescriptor].self, forKey: .emitters)
        try validate()
    }
}

public enum ParticleEffectError: Error, LocalizedError, Sendable {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): message }
    }
}
