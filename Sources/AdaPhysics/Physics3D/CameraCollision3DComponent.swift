import AdaECS
import AdaTransform
import AdaUtils
import Foundation
import Math

/// Resolves a world-space camera eye against static physics geometry, then looks at `target`.
/// Author orbit/follow behavior in scripts by updating `origin`, `destination` and `target`.
@Component
public struct CameraCollision3DComponent: Codable, Sendable {
    public var origin: Vector3 = .zero
    public var destination: Vector3 = [0, 0, -6]
    public var target: Vector3 = .zero
    public var radius: Float = 0.24
    public var margin: Float = 0.08
    public var recoverySpeed: Float = 5
    public var actualDistance: Float = 6.6
    public internal(set) var isOccluded: Bool = false

    public init() {}
}

/// Sphere-sweeps camera placement before transform propagation; retracts immediately and recovers smoothly.
@PlainSystem(dependencies: [.before(TransformSystem.self)])
public struct CameraCollision3DSystem {
    @Query<Ref<CameraCollision3DComponent>, Ref<Transform>> private var cameras
    @ResMut<Physics3DWorldHolder> private var physics
    @Res<DeltaTime?> private var time

    public init(world _: World) {}

    @MainActor
    public func update(context _: UpdateContext) {
        let delta = time?.deltaTime ?? 0
        let dt = delta.isFinite ? min(max(delta, 0), 0.1) : 0
        cameras.forEach { control, transform in
            let travel = control.destination - control.origin
            guard travel.length.isFinite, travel.length > 0.0001, control.target.length.isFinite,
                control.radius.isFinite, control.radius > 0, control.margin.isFinite,
                control.recoverySpeed.isFinite, control.actualDistance.isFinite else { return }
            let fraction = physics.world.sphereCastFraction(from: control.origin, to: control.destination, radius: control.radius)
            let allowed = max(0, travel.length * fraction - max(0, control.margin))
            control.isOccluded = fraction < 0.99
            let previous = max(0, control.actualDistance)
            control.actualDistance = allowed < previous ? allowed
                : previous + (allowed - previous) * Float(1 - exp(-Double(dt * max(0, control.recoverySpeed))))
            let eye = control.origin + travel.normalized * control.actualDistance
            var forward = control.target - eye
            if forward.length < 0.0001 { forward = [0, 0, 1] }
            forward = forward.normalized
            let referenceUp: Vector3 = abs(forward.y) > 0.999 ? [0, 0, 1] : .up
            let right = referenceUp.cross(forward).normalized
            let up = forward.cross(right)
            transform.wrappedValue = Transform(matrix: Transform3D(Vector4(right, 0), Vector4(up, 0), Vector4(forward, 0), Vector4(eye, 1)))
        }
    }
}
