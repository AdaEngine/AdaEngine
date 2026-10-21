/// Higher raw values win ties between materials of equal priority. Native defaults have the lowest precedence.
public enum PhysicsMaterialCombineRule: UInt8, Codable, CaseIterable, Sendable {
    case nativeDefault = 0
    case minimum = 1
    case geometricMean = 2
    case average = 3
    case multiply = 4
    case maximum = 5

    func combine(_ a: Float, _ b: Float, restitution: Bool) -> Float {
        switch self {
        case .nativeDefault:
            return restitution ? max(a, b) : Self.geometricMean.combine(a, b, restitution: false)
        case .minimum: return min(a, b)
        case .maximum: return max(a, b)
        case .average: return a * 0.5 + b * 0.5
        case .multiply:
            let result = a * b
            return result.isFinite ? result : Float.greatestFiniteMagnitude
        case .geometricMean:
            let product = a * b
            return product.isFinite ? product.squareRoot() : a.squareRoot() * b.squareRoot()
        }
    }
}

/// Immutable, worker-safe policy. Higher priority wins, then the rule's raw value; A/B ordering never matters.
/// The low 32 native material-ID bits hold identifier. Upper bits are reserved for AdaPhysics policies.
public struct PhysicsMaterialMixing: Codable, Equatable, Sendable {
    public var friction: PhysicsMaterialCombineRule = .nativeDefault
    public var restitution: PhysicsMaterialCombineRule = .nativeDefault
    public var priority: UInt8 = 0
    public var identifier: UInt32 = 0
    public init() {}

    var nativeID: UInt64 {
        UInt64(identifier) | UInt64(priority) << 32 | UInt64(friction.rawValue) << 40 | UInt64(restitution.rawValue) << 48 | UInt64(0xA2) << 56
    }

    static func rule(_ id: UInt64, restitution: Bool) -> (UInt16, PhysicsMaterialCombineRule) {
        guard id >> 56 == 0xA2 else {
            return (0, .nativeDefault)
        }
        let raw = UInt8(truncatingIfNeeded: id >> (restitution ? 48 : 40))
        let rule = PhysicsMaterialCombineRule(rawValue: raw) ?? .nativeDefault
        return (UInt16(UInt8(truncatingIfNeeded: id >> 32)) << 8 | UInt16(rule.rawValue), rule)
    }

    static func combine(_ a: Float, idA: UInt64, _ b: Float, idB: UInt64, restitution: Bool) -> Float {
        let left = rule(idA, restitution: restitution)
        let right = rule(idB, restitution: restitution)
        return (left.0 >= right.0 ? left.1 : right.1).combine(a, b, restitution: restitution)
    }
}

// C callbacks are pure: no captured world, registry, lock, allocation or application mutation on native workers.
func Physics2D_Friction(_ a: Float, _ idA: UInt64, _ b: Float, _ idB: UInt64) -> Float {
    PhysicsMaterialMixing.combine(a, idA: idA, b, idB: idB, restitution: false)
}

func Physics2D_Restitution(_ a: Float, _ idA: UInt64, _ b: Float, _ idB: UInt64) -> Float {
    PhysicsMaterialMixing.combine(a, idA: idA, b, idB: idB, restitution: true)
}
