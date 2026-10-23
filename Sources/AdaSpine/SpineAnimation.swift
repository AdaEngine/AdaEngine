import AdaApp
import AdaAssets
import AdaECS
import AdaRender
import AdaSpineRuntime
import AdaTransform
import AdaUtils

/// Add this to a character entity in a scene viewed by a 2D camera.
/// Playback belongs to the player reference; initialize a component per character.
@Component(required: [GlobalTransform.self, Visibility.self, BoundingComponent.self])
public struct SpineAnimation: Sendable {
    public let skeleton: SpineSkeleton
    public let player: SpineAnimationPlayer
    public var isPaused: Bool = false
    /// Non-negative playback speed. Invalid values freeze playback.
    public var speed: Float = 1

    public init(skeleton: SpineSkeleton) throws {
        self.skeleton = skeleton
        self.player = try skeleton.makePlayer()
    }
}

/// Add alongside AdaEngine's default plugins (including Core2DPlugin).
public struct SpinePlugin: Plugin {
    public init() {}

    public func setup(in app: AppWorlds) {
        SpineAnimation.registerComponent()
        SpineDebugBones.registerComponent()
        RuntimeTypeRegistry.registerComponent(SpineSource.self, names: ["SpineSource"])
        AssetsManager.registerAssetType(SpineSkeleton.self)
        app.addSystem(SpineSourceSystem.self, on: .update)
        app.addSystem(SpineAnimationSystem.self, on: .update)
        app.getSubworldBuilder(by: .renderWorld)?
            .insertResource(ExtractedSpineDraws())
            .insertResource(SpineRenderData())
            .addSystem(ExtractSpineSystem.self, on: .extract)
            .addSystem(PrepareSpineSystem.self, on: .preUpdate)
    }
}

@PlainSystem
struct SpineAnimationSystem {
    @Query<Ref<SpineAnimation>> private var animations
    @FilterQuery<Entity, And<With<SpineAnimation>, Without<NoFrustumCulling>>> private var unbounded
    @Commands private var commands
    @Res<DeltaTime> private var time

    init(world _: World) {}

    func update(context _: UpdateContext) {
        unbounded.forEach { entity in commands.entity(entity.id).insert(NoFrustumCulling()) }
        animations.forEach { animation in
            guard !animation.isPaused, animation.speed.isFinite, animation.speed >= 0 else { return }
            let player = animation.wrappedValue.player
            player.advance(by: time.deltaTime * animation.speed)
        }
    }
}
