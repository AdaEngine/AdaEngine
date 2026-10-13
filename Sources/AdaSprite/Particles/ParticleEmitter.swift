import AdaAssets
import AdaECS
import AdaRender
import AdaTransform

/// Instance-owned playback of a `.particles` asset. Increment `restartCount` to replay a one-shot effect.
@Component(required: [GlobalTransform.self, Visibility.self, BoundingComponent.self])
public struct ParticleEmitter: Codable, Sendable {
    public var effect: AssetHandle<ParticleEffect>?
    /// Stop spawning while allowing live particles to expire.
    public var isEmitting: Bool
    /// Freeze both emission and live particles.
    public var isPaused: Bool
    public var restartCount: Int
    var simulation: ParticleSimulation?
    var appliedRestartCount: Int = 0

    /// Current live count, available to inspectors without exposing simulation buffers.
    public var particleCount: Int { simulation?.particleCount ?? 0 }

    @AdaScriptInit
    public init(effect: AssetHandle<ParticleEffect>? = nil, isEmitting: Bool = true, isPaused: Bool = false, restartCount: Int = 0) {
        self.effect = effect
        self.isEmitting = isEmitting
        self.isPaused = isPaused
        self.restartCount = restartCount
    }

    private enum CodingKeys: CodingKey { case effect, isEmitting, isPaused, restartCount }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            effect: try values.decodeIfPresent(AssetHandle<ParticleEffect>.self, forKey: .effect),
            isEmitting: try values.decodeIfPresent(Bool.self, forKey: .isEmitting) ?? true,
            isPaused: try values.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false,
            restartCount: try values.decodeIfPresent(Int.self, forKey: .restartCount) ?? 0
        )
    }
}
