import AdaAssets
import AdaECS
import AdaRender
import AdaUtils
import Foundation
import Math

/// A portable Spine reference, saved by scene editors. The plugin creates independent playback per entity.
@Component
public struct SpineSource: Codable, Equatable, Sendable {
    public var source: String
    public var animation: String
    public var skin: String
    public var autoplay: Bool
    public var repeats: Bool
    public var speed: Float
    public var showBones: Bool

    public init(source: String = "", animation: String = "", skin: String = "", autoplay: Bool = true,
                repeats: Bool = true, speed: Float = 1, showBones: Bool = false) {
        self.source = source
        self.animation = animation
        self.skin = skin
        self.autoplay = autoplay
        self.repeats = repeats
        self.speed = speed
        self.showBones = showBones
    }

    /// Installs a loaded skeleton on an owner. Validation happens before changing the entity.
    public func instantiate(_ skeleton: SpineSkeleton, on entity: Entity) throws {
        guard speed.isFinite, speed >= 0 else { throw SpineError.invalidTime }
        var component = try SpineAnimation(skeleton: skeleton)
        if !skin.isEmpty { try component.player.setSkin(skin) }
        if !animation.isEmpty { try component.player.play(animation, repeats: repeats, transitionDuration: 0) }
        component.isPaused = !autoplay
        component.speed = speed
        entity.components[SpineSource.self] = self
        let vertices = component.player.snapshot().flatMap(\.vertices)
        if let first = vertices.first {
            var lower = Vector3(first.x, first.y, 0)
            var upper = lower
            for vertex in vertices {
                lower.x = min(lower.x, vertex.x); lower.y = min(lower.y, vertex.y)
                upper.x = max(upper.x, vertex.x); upper.y = max(upper.y, vertex.y)
            }
            entity.components[BoundingComponent.self] = BoundingComponent(bounds: .aabb(AABB(min: lower, max: upper)))
        }
        entity.components[SpineAnimation.self] = component
        entity.components[NoFrustumCulling.self] = NoFrustumCulling()
        entity.components[SpineDebugBones.self] = showBones ? SpineDebugBones() : nil
        entity.components[SpineSourceState.self] = .init(reference: self)
    }
}

/// Enables a native bone overlay in skeleton space. It is optional and never changes the pose.
@Component
public struct SpineDebugBones: Sendable {
    public var width: Float
    public var color: Color
    public init(width: Float = 3, color: Color = Color(0.15, 1, 0.75, 1)) {
        self.width = width
        self.color = color
    }
}

/// Load status for a portable Spine reference; generated playback is not serialized.
public struct SpineSourceState: Component {
    public let reference: SpineSource
    public let error: String?
    public init(reference: SpineSource, error: String? = nil) { self.reference = reference; self.error = error }
}

@PlainSystem
struct SpineSourceSystem {
    @Query<Entity, SpineSource> private var sources
    @Query<Entity, SpineSourceState> private var instances
    @Commands private var commands
    init(world _: World) {}

    func update(context _: UpdateContext) async {
        var pending: [(Entity.ID, SpineSource)] = []
        sources.forEach { entity, source in
            if entity.components[SpineSourceState.self]?.reference != source { pending.append((entity.id, source)) }
        }
        instances.forEach { entity, _ in
            if entity.components[SpineSource.self] == nil {
                let id = entity.id
                commands.queue.push { world in
                    guard let owner = world.getEntityByID(id), owner.components[SpineSource.self] == nil else { return }
                    owner.components[SpineAnimation.self] = nil
                    owner.components[SpineDebugBones.self] = nil
                    owner.components[SpineSourceState.self] = nil
                }
            }
        }
        for (id, source) in pending {
            let result: Result<SpineSkeleton?, SpineError>
            do { result = .success(source.source.isEmpty ? nil : try await AssetsManager.load(SpineSkeleton.self, at: source.source).asset) }
            catch { result = .failure(.invalidData(error.localizedDescription)) }
            commands.queue.push { world in
                guard let owner = world.getEntityByID(id), owner.components[SpineSource.self] == source,
                      owner.components[SpineSourceState.self]?.reference != source else { return }
                owner.components[SpineAnimation.self] = nil
                owner.components[SpineDebugBones.self] = nil
                do {
                    if let skeleton = try result.get() { try source.instantiate(skeleton, on: owner) }
                    else { owner.components[SpineSourceState.self] = .init(reference: source) }
                } catch { owner.components[SpineSourceState.self] = .init(reference: source, error: error.localizedDescription) }
            }
        }
    }
}
