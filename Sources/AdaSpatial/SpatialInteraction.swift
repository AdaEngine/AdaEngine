import AdaECS
import AdaTransform
import Math

/// Optional analytic surface for a gizmo ring or palm menu sector.
public enum SpatialGrabShape: Sendable {
    case box
    case ring(axis: Int, innerRadius: Float, outerRadius: Float, startAngle: Float = 0, endAngle: Float = .pi * 2)
}

/// Marks an entity as manipulable. Bounds are local half extents in meters.
/// Grabs operate in world space and write the result back in the parent coordinate system.
@Component
public struct SpatialGrabbable: Sendable {
    public var center: Vector3
    public var shape: SpatialGrabShape
    public var allowsManipulation: Bool
    public var halfExtents: Vector3
    public var directGrabMargin: Float

    public init(halfExtents: Vector3, directGrabMargin: Float = 0.06, center: Vector3 = .zero, shape: SpatialGrabShape = .box, allowsManipulation: Bool = true) {
        self.center = center
        self.shape = shape
        self.allowsManipulation = allowsManipulation
        self.halfExtents = halfExtents
        self.directGrabMargin = directGrabMargin
    }
}

/// Selection survives release so an inspector can continue editing the last selected object.
public struct SpatialSelection: Resource {
    public var entityID: Entity.ID?
    public var isGrabbed: Bool

    public init(entityID: Entity.ID? = nil, isGrabbed: Bool = false) {
        self.entityID = entityID
        self.isGrabbed = isGrabbed
    }
}

/// Restricts an immersive editor grab without changing the default free manipulation behavior.
public enum SpatialManipulationMode: String, CaseIterable, Sendable {
    case free
    case select
    case translate
    case rotate
    case scale
}

/// Optional policy for the spatial interaction system. Missing settings use free manipulation.
public struct SpatialInteractionSettings: Resource {
    public var mode: SpatialManipulationMode

    public init(mode: SpatialManipulationMode = .free) {
        self.mode = mode
    }
}

/// Keeps offsets at grab time and rebases whenever the number of gripping hands changes.
struct SpatialGrabSession {
    var entityID: Entity.ID
    var interactors: [SpatialInteractor]
    var objectStart: Transform
    var poseStart: Transform3D
    var secondaryStart: Vector3?
    var mode: SpatialManipulationMode

    init(entityID: Entity.ID, object: Transform, grips: [SpatialGrip], mode: SpatialManipulationMode = .free) {
        self.entityID = entityID
        self.mode = mode
        self.interactors = grips.map(\.interactor)
        self.objectStart = object
        self.poseStart = grips[0].pose
        self.secondaryStart = grips.count == 2 ? grips[1].pose.origin : nil
    }

    func transform(grips: [SpatialGrip]) -> Transform {
        let result = freeTransform(grips: grips)
        switch mode {
        case .free: return result
        case .select: return objectStart
        case .translate: return Transform(rotation: objectStart.rotation, scale: objectStart.scale, position: result.position)
        case .rotate: return Transform(rotation: result.rotation, scale: objectStart.scale, position: objectStart.position)
        case .scale: return Transform(rotation: objectStart.rotation, scale: result.scale, position: objectStart.position)
        }
    }

    private func freeTransform(grips: [SpatialGrip]) -> Transform {
        guard let first = grips.first else {
            return objectStart
        }
        guard let secondaryStart, grips.count == 2 else {
            let delta = first.pose * poseStart.inverse
            return Transform(
                rotation: (Transform3D(quat: delta.rotation) * Transform3D(quat: objectStart.rotation)).rotation,
                scale: objectStart.scale,
                position: (delta * Vector4(objectStart.position, 1)).xyz
            )
        }
        let startVector = secondaryStart - poseStart.origin
        let currentVector = grips[1].pose.origin - first.pose.origin
        guard startVector.length > 0.02, currentVector.length > 0.02 else {
            return objectStart
        }
        let ratio = min(max(currentVector.length / startVector.length, 0.1), 10)
        let rotation = Self.rotation(from: startVector.normalized, to: currentVector.normalized)
        let startCenter = (secondaryStart + poseStart.origin) * 0.5
        let currentCenter = (grips[1].pose.origin + first.pose.origin) * 0.5
        let rotatedOffset = (Transform3D(quat: rotation) * Vector4((objectStart.position - startCenter) * ratio, 0)).xyz
        return Transform(
            rotation: (Transform3D(quat: rotation) * Transform3D(quat: objectStart.rotation)).rotation,
            scale: objectStart.scale * ratio,
            position: currentCenter + rotatedOffset
        )
    }

    private static func rotation(from start: Vector3, to end: Vector3) -> Quat {
        let dot = min(max(start.dot(end), -1), 1)
        if dot > 0.9999 {
            return .identity
        }
        if dot < -0.9999 {
            let axis = start.cross(abs(start.x) < 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0)).normalized
            return Quat(axis: axis, angle: .pi)
        }
        let cross = start.cross(end)
        let divisor = Math.sqrt(2 * (1 + dot))
        return Quat(x: cross.x / divisor, y: cross.y / divisor, z: cross.z / divisor, w: divisor * 0.5)
    }
}

/// One object may be held by up to two interactors. Changes apply through writable ECS queries.
@PlainSystem
public struct SpatialInteractionSystem {
    @Query<Entity, Ref<Transform>, SpatialGrabbable> private var objects
    @Res<SpatialInput> private var input
    @ResMut<SpatialSelection> private var selection
    @Res<SpatialInteractionSettings?> private var settings
    @Local private var session: SpatialGrabSession?
    @Local private var previousInteractors: Set<SpatialInteractor> = []

    public init(world _: World) {}

    public func update(context _: UpdateContext) {
        // Reject invalid poses before they can poison a scene transform.
        let grips = input.grips.filter { grip in
            abs(grip.pose.determinant) > 0.0001
                && (0..<4).allSatisfy { column in
                    (0..<4).allSatisfy { row in grip.pose[column, row].isFinite }
                }
        }
        let mode = settings?.mode ?? .free
        if mode == .select { session = nil }
        let current = Set(grips.map(\.interactor))
        defer { previousInteractors = current }
        if let active = session {
            var found = false
            objects.forEach { entity, transform, bounds in
                guard entity.id == active.entityID else {
                    return
                }
                found = true
                let parent = Self.parentMatrix(of: entity)
                guard abs(parent.determinant) > 0.0001 else {
                    session = nil
                    return
                }
                let objectMatrix = parent * transform.wrappedValue.matrix
                let held = active.interactors.compactMap { interactor in grips.first { $0.interactor == interactor } }
                guard !held.isEmpty else {
                    session = nil
                    return
                }
                var attached = held
                if attached.count == 1,
                    let joining = grips.first(where: {
                        !active.interactors.contains($0.interactor)
                            && !previousInteractors.contains($0.interactor)
                            && Self.hitDistance($0, matrix: objectMatrix, bounds: bounds) != nil
                    }) {
                    attached.append(joining)
                }
                if attached.map(\.interactor) != active.interactors || mode != active.mode {
                    // Rebase at the current transform: adding/releasing a hand must not jump.
                    session = SpatialGrabSession(entityID: entity.id, object: Self.decompose(objectMatrix), grips: attached, mode: mode)
                } else {
                    transform.wrappedValue = Self.decompose(parent.inverse * active.transform(grips: attached).matrix)
                }
            }
            if !found {
                session = nil
                selection.entityID = nil
            }
        } else {
            // A held pinch that started in empty space must not suddenly acquire an object.
            for grip in grips where !previousInteractors.contains(grip.interactor) {
                var candidate: (Entity.ID, Transform, Float, Bool)?
                objects.forEach { entity, transform, bounds in
                    let matrix = Self.parentMatrix(of: entity) * transform.wrappedValue.matrix
                    if let distance = Self.hitDistance(grip, matrix: matrix, bounds: bounds),
                        candidate == nil || distance < (candidate?.2 ?? .infinity) {
                        candidate = (entity.id, Self.decompose(matrix), distance, bounds.allowsManipulation)
                    }
                }
                if let candidate {
                    if mode != .select && candidate.3 {
                        session = SpatialGrabSession(entityID: candidate.0, object: candidate.1, grips: [grip], mode: mode)
                    }
                    selection.entityID = candidate.0
                    break
                } else if mode == .select {
                    selection.entityID = nil
                }
            }
        }
        selection.isGrabbed = session != nil
    }

    private static func decompose(_ matrix: Transform3D) -> Transform {
        let scale = matrix.scale
        var rotation = matrix
        for column in 0..<3 where scale[column] > 0.0001 {
            for row in 0..<3 { rotation[column, row] /= scale[column] }
        }
        return Transform(rotation: rotation.rotation.normalized, scale: scale, position: matrix.origin)
    }

    private static func parentMatrix(of entity: Entity) -> Transform3D {
        var matrix = Transform3D.identity
        var parent = entity.parent
        while let current = parent {
            matrix = (current.components[Transform.self]?.matrix ?? .identity) * matrix
            parent = current.parent
        }
        return matrix
    }

    private static func hitDistance(_ grip: SpatialGrip, matrix: Transform3D, bounds: SpatialGrabbable) -> Float? {
        let scale = matrix.scale
        guard scale.x > 0, scale.y > 0, scale.z > 0, abs(matrix.determinant) > 0.0001 else {
            return nil
        }
        let inverse = matrix.inverse
        let extent = bounds.halfExtents
        guard extent.x > 0, extent.y > 0, extent.z > 0 else {
            return nil
        }
        if case let .ring(axis, inner, outer, start, end) = bounds.shape {
            guard (0..<3).contains(axis) else { return nil }
            let origin = (inverse * Vector4(grip.ray?.origin ?? grip.pose.origin, 1)).xyz - bounds.center
            let direction = grip.ray.map { (inverse * Vector4($0.direction, 0)).xyz }
            let distance: Float
            let point: Vector3
            if let direction {
                guard abs(direction[axis]) > 0.00001 else { return nil }
                distance = -origin[axis] / direction[axis]
                guard distance >= 0 else { return nil }
                point = origin + direction * distance
            } else {
                guard abs(origin[axis]) < bounds.directGrabMargin / scale[axis] else { return nil }
                point = origin
                distance = (grip.pose.origin - matrix.origin).length
            }
            let x = point[(axis + 1) % 3]
            let y = point[(axis + 2) % 3]
            let radius = sqrt(x * x + y * y)
            var angle = atan2(y, x)
            if angle < 0 { angle += .pi * 2 }
            return radius >= inner && radius <= outer && angle >= start && angle <= end ? distance : nil
        }
        guard let ray = grip.ray else {
            let local = (inverse * Vector4(grip.pose.origin, 1)).xyz - bounds.center
            let margin = max(0, bounds.directGrabMargin)
            if abs(local.x) <= extent.x + margin / scale.x,
                abs(local.y) <= extent.y + margin / scale.y,
                abs(local.z) <= extent.z + margin / scale.z {
                return (grip.pose.origin - (matrix * Vector4(bounds.center, 1)).xyz).length
            }
            return nil
        }
        guard (0..<3).allSatisfy({ ray.origin[$0].isFinite && ray.direction[$0].isFinite }) else {
            return nil
        }
        let origin = (inverse * Vector4(ray.origin, 1)).xyz - bounds.center
        let direction = (inverse * Vector4(ray.direction, 0)).xyz
        guard direction.length > 0.0001 else {
            return nil
        }
        var near: Float = 0
        var far: Float = .infinity
        for axis in 0..<3 {
            if abs(direction[axis]) < 0.00001 {
                if abs(origin[axis]) > extent[axis] {
                    return nil
                }
            } else {
                let a = (-extent[axis] - origin[axis]) / direction[axis]
                let b = (extent[axis] - origin[axis]) / direction[axis]
                near = max(near, min(a, b))
                far = min(far, max(a, b))
                if near > far {
                    return nil
                }
            }
        }
        return near
    }
}
