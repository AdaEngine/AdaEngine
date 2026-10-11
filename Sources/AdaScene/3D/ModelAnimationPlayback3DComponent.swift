import AdaAnimation
import AdaECS

/// Serializable playback controls on a model owner. Scripts can select clips without
/// holding the imported model's instance-local animation player.
@Component
public struct ModelAnimationPlayback3DComponent: Codable, Sendable {
    public var clip: String = ""
    public var speed: Double = 1
    public var repeats: Bool = true
    public var isPlaying: Bool = true
    public var transitionDuration: Double = 0.22
    /// Preserve normalized cycle time when switching between looping clips.
    public var synchronizePhase: Bool = false

    public init() {}
}

/// Applies owner controls before evaluating imported poses. Each model retains its own clock.
@PlainSystem(dependencies: [.before(SkeletalAnimation3DSystem.self)])
public struct ModelAnimationPlayback3DSystem {
    @Query<ModelAnimationPlayback3DComponent, Model3DSourceState> private var controls
    @Query<Entity, Ref<ModelAnimation3DComponent>> private var models

    public init(world _: World) {}

    public func update(context _: UpdateContext) {
        var byRoot: [Entity.ID: ModelAnimationPlayback3DComponent] = [:]
        controls.forEach { control, state in
            if let root = state.rootEntityID { byRoot[root] = control }
        }
        models.forEach { entity, animation in
            guard let control = byRoot[entity.id], control.speed.isFinite,
                control.transitionDuration.isFinite, control.transitionDuration >= 0 else { return }
            var player = animation.player
            let oldClip = player.clipIndex.map { player.clips[$0] }
            if !control.clip.isEmpty, oldClip?.name != control.clip {
                guard let next = player.clips.first(where: { $0.name == control.clip }) else { return }
                let phase = control.synchronizePhase && player.repeats && control.repeats && (oldClip?.duration ?? 0) > 0
                    ? player.time.truncatingRemainder(dividingBy: oldClip?.duration ?? 1) / (oldClip?.duration ?? 1) : 0
                do {
                    try player.play(control.clip, transitionDuration: control.transitionDuration, startTime: phase * next.duration)
                } catch { return }
            }
            player.speed = control.speed
            player.repeats = control.repeats
            player.isPlaying = control.isPlaying
            animation.player = player
        }
    }
}
