import AdaECS
import AdaTransform
import box2d
import Math

public enum PhysicsCoordinate2DError: String, Codable, Sendable {
    case invalidPosition
    case parentedEntity
}

/// Authoritative global XY position for a root entity, including nonphysical roots such as cameras.
/// Transform.position.xy is projected relative to PhysicsWorld2D.coordinateOrigin during physicsSync.
/// Edit this position to teleport; editing only the projected Transform is overwritten by synchronization.
@Component
public struct PhysicsPosition2DComponent: Codable, Sendable {
    public var position: PhysicsPosition2D
    public internal(set) var lastError: PhysicsCoordinate2DError?

    public init(_ position: PhysicsPosition2D) { self.position = position }
}

extension PhysicsWorld2D {
    /// Changes only the frame used by Float APIs/render transforms. Native global bodies are not teleported.
    /// Call between simulation steps; root projections update on the next physicsSync.
    @MainActor
    @discardableResult
    public func setCoordinateOrigin(_ origin: PhysicsPosition2D) -> Bool {
        guard origin.isFinite else {
            return false
        }
        coordinateOrigin = origin
        return true
    }

    func nativePosition(_ local: Vector2) -> b2Pos { coordinateOrigin.offset(by: local).native }
    func localPosition(_ global: b2Pos) -> Vector2 { PhysicsPosition2D(global).displacement(from: coordinateOrigin) }

    func authoredPosition(_ entity: Entity, fallback: Vector2) -> b2Pos? {
        guard let coordinate = entity.components[PhysicsPosition2DComponent.self] else {
            return nativePosition(fallback)
        }
        guard coordinate.position.isFinite, entity.components[RelationshipComponent.self]?.parent == nil else {
            return nil
        }
        return coordinate.position.native
    }
}

/// Projects only explicitly authored global roots. Children inherit their parent's nearby frame normally.
@PlainSystem(dependencies: [.before(Physics2DSyncSystem.self)])
public struct PhysicsCoordinate2DSyncSystem {
    @Query<Entity, Ref<PhysicsPosition2DComponent>, Ref<Transform>> private var roots
    @PhysicsHierarchyAccess2D private var hierarchy
    @Res<Physics2DWorldHolder> private var physics
    public init(world _: World) {}

    @MainActor
    public func update(context _: UpdateContext) {
        roots.forEach { entity, coordinate, transform in
            guard entity.components[RelationshipComponent.self]?.parent == nil else {
                coordinate.lastError = .parentedEntity
                return
            }
            guard coordinate.position.isFinite else {
                coordinate.lastError = .invalidPosition
                return
            }
            let local = coordinate.position.displacement(from: physics.world.coordinateOrigin)
            guard local.x.isFinite, local.y.isFinite else {
                coordinate.lastError = .invalidPosition
                return
            }
            coordinate.lastError = nil
            if transform.position.xy != local { transform.position.x = local.x; transform.position.y = local.y }
        }
    }
}

@propertyWrapper
struct PhysicsHierarchyAccess2D: SystemParameter {
    var wrappedValue: Self { self }
    init() {}
    init(from _: World) {}
    func update(from _: World) {}
    static var access: SystemAccessSet {
        var access = SystemAccessSet()
        access.addComponentRead(RelationshipComponent.self)
        return access
    }
}

@propertyWrapper
struct PhysicsCoordinateAccess2D: SystemParameter {
    var wrappedValue: Self { self }
    init() {}
    init(from _: World) {}
    func update(from _: World) {}
    static var access: SystemAccessSet {
        var access = PhysicsHierarchyAccess2D.access
        access.addComponentRead(PhysicsPosition2DComponent.self)
        return access
    }
}

@propertyWrapper
struct PhysicsCoordinateWriteAccess2D: SystemParameter {
    var wrappedValue: Self { self }
    init() {}
    init(from _: World) {}
    func update(from _: World) {}
    static var access: SystemAccessSet {
        var access = SystemAccessSet()
        access.addComponentWrite(PhysicsPosition2DComponent.self)
        return access
    }
}
