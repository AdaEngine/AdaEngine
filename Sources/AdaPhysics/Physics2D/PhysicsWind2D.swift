import AdaECS
import box2d
import Math

public enum PhysicsWind2DError: String, Error, Codable, Sendable { case invalidSettings }

/// Box2D's projected-area wind model. Velocity is world-space airflow; local geometry/relative motion determine force.
/// Drag and lift are passed to the native model (lift is shape-dependent). This is independent of body damping.
public struct PhysicsWind2D: Codable, Equatable, Sendable {
    public var velocity: Vector2
    public var drag: Float
    public var lift: Float
    public var wakeSleepingBodies: Bool
    public var includeSensors: Bool

    public init(velocity: Vector2 = .zero, drag: Float = 1, lift: Float = 0, wakeSleepingBodies: Bool = false, includeSensors: Bool = false) {
        self.velocity = velocity; self.drag = drag; self.lift = lift
        self.wakeSleepingBodies = wakeSleepingBodies; self.includeSensors = includeSensors
    }

    func validate() throws(PhysicsWind2DError) {
        guard velocity.x.isFinite, velocity.y.isFinite, velocity.squaredLength.isFinite,
            drag.isFinite, drag >= 0, lift.isFinite else { throw .invalidSettings }
    }
}

/// Opt-in aerodynamic force applied once before each native fixed step. No component means no extra force.
@Component
public struct PhysicsWind2DComponent: Codable, Sendable {
    public var settings: PhysicsWind2D
    public internal(set) var lastError: PhysicsWind2DError?
    public init(_ settings: PhysicsWind2D = .init()) { self.settings = settings }
    private enum CodingKeys: CodingKey { case settings }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        settings = try values.decode(PhysicsWind2D.self, forKey: .settings)
        try settings.validate()
    }
    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(settings, forKey: .settings)
    }
}

@MainActor
extension PhysicsBody2DComponent {
    /// Accumulates native force for the next step. Call once per desired step, not once per render frame.
    /// Returns whether eligible dynamic geometry was submitted; sleeping bodies can ignore it when wake is false.
    /// Sensors are excluded by default, and native unsupported line shapes receive no aerodynamic force.
    @discardableResult
    public func applyWind(_ settings: PhysicsWind2D) throws(PhysicsWind2DError) -> Bool {
        try settings.validate()
        guard let body = runtimeBody, body.world != nil, b2Body_IsValid(body.bodyId),
            b2Body_IsEnabled(body.bodyId), b2Body_GetType(body.bodyId) == b2_dynamicBody else {
            return false
        }
        var submitted = false
        body.forEachNativeShape { id in
            guard b2Shape_IsValid(id), settings.includeSensors || !b2Shape_IsSensor(id) else {
                return
            }
            let type = b2Shape_GetType(id)
            guard type == b2_circleShape || type == b2_capsuleShape || type == b2_polygonShape else {
                return
            }
            // In 3.2 ApplyWind obtains its body-sim pointer before waking/moving sleeping storage.
            // Wake first so the native force calculation always uses the current awake allocation.
            if settings.wakeSleepingBodies && !b2Body_IsAwake(body.bodyId) { b2Body_SetAwake(body.bodyId, true) }
            b2Shape_ApplyWind(id, settings.velocity.b2Vec, settings.drag, settings.lift, false)
            submitted = true
        }
        return submitted
    }
}

@PlainSystem
public struct PhysicsWind2DSystem {
    public static var dependencies: [SystemDependency] { [.after(DynamicCharacter2DControlSystem.self), .before(Physics2DUpdateSystem.self)] }
    @Query<Ref<PhysicsWind2DComponent>, PhysicsBody2DComponent> private var bodies
    @Res<Physics2DWorldHolder> private var physics
    public init(world _: World) {}

    @MainActor
    public func update(context _: UpdateContext) {
        bodies.forEach { wind, body in
            guard body.runtimeBody?.world === physics.world else {
                return
            }
            do throws(PhysicsWind2DError) {
                try body.applyWind(wind.settings)
                wind.lastError = nil
            } catch { wind.lastError = error }
        }
    }
}
