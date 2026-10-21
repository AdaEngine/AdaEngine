import AdaECS
import box2d
import Math

/// The main actor owns all joint mutations. Native lifetime is bounded by PhysicsWorld2D.
@MainActor
final class RuntimeJoint2D {
    weak var world: PhysicsWorld2D?
    var descriptor: PhysicsJoint2DDescriptor
    private(set) var id: b2JointId
    let bodyA: b2BodyId
    let bodyB: b2BodyId
    let ownedAnchor: b2BodyId?

    init(world: PhysicsWorld2D, descriptor: PhysicsJoint2DDescriptor, id: b2JointId, bodyA: b2BodyId, bodyB: b2BodyId, ownedAnchor: b2BodyId? = nil) {
        self.world = world
        self.descriptor = descriptor
        self.id = id
        self.bodyA = bodyA
        self.bodyB = bodyB
        self.ownedAnchor = ownedAnchor
    }
    var isConnected: Bool { world != nil && b2Joint_IsValid(id) }
    func destroy() {
        if isConnected {
            // DestroyJoint wakes bodies but does not mark stationary proxies for pair discovery.
            // Restore pair collision first so removing a non-colliding constraint refilters overlaps.
            b2Joint_SetCollideConnected(id, true)
            b2DestroyJoint(id)
        }
        id = b2_nullJointId
        if world != nil, let ownedAnchor, b2Body_IsValid(ownedAnchor) { b2DestroyBody(ownedAnchor) }
    }

    static func body(_ entity: Entity?) -> Body2D? {
        entity?.components[PhysicsBody2DComponent.self]?.runtimeBody ?? entity?.components[Collision2DComponent.self]?.runtimeBody
    }

    static func endpoints(_ descriptor: PhysicsJoint2DDescriptor) -> (Entity.ID?, Entity.ID)? {
        switch descriptor.joint {
        case let .rope(a, b, _, _), let .distance(a, b, _), let .hinge(a, b, _): return (a, b)
        case let .wheel(a, b, _), let .motor(a, b, _): return (a, b)
        case let .revolute(b), let .worldHinge(b, _, _): return (nil, b)
        case let .prismatic(a, b, _), let .weld(a, b, _), let .filter(a, b): return (a, b)
        }
    }

    func matches(a: Body2D?, b: Body2D) -> Bool {
        let sameA = a.map { b2StoreBodyId($0.bodyId) == b2StoreBodyId(bodyA) } ?? (ownedAnchor != nil)
        return isConnected && sameA && b2StoreBodyId(bodyB) == b2StoreBodyId(b.bodyId)
    }

    static func connection(_ value: b2JointDef, a: b2BodyId, b: b2BodyId, frameA: JointFrame2D, frameB: JointFrame2D, collide: Bool) -> b2JointDef {
        var result = value
        result.bodyIdA = a
        result.bodyIdB = b
        result.localFrameA = frameA.native
        result.localFrameB = frameB.native
        result.collideConnected = collide
        return result
    }

    static func make(_ descriptor: PhysicsJoint2DDescriptor, a: Body2D?, b: Body2D, world: PhysicsWorld2D) throws(PhysicsJoint2DError) -> RuntimeJoint2D {
        guard b.world === world, a == nil || a?.world === world,
            a == nil || b2StoreBodyId(a?.bodyId ?? b2_nullBodyId) != b2StoreBodyId(b.bodyId),
            b2Body_GetType(b.bodyId) == b2_dynamicBody || (a != nil && b2Body_GetType(a?.bodyId ?? b2_nullBodyId) == b2_dynamicBody) else {
            throw .invalidBodyPair
        }
        let ownedAnchor: b2BodyId?
        if a == nil {
            var definition = unsafe b2DefaultBodyDef()
            ownedAnchor = unsafe b2CreateBody(world.worldId, &definition)
        } else { ownedAnchor = nil }
        let bodyA = a?.bodyId ?? ownedAnchor ?? b2_nullBodyId
        var id = b2_nullJointId
        defer {
            if let ownedAnchor, !b2Joint_IsValid(id), b2Body_IsValid(ownedAnchor) { b2DestroyBody(ownedAnchor) }
        }
        switch descriptor.joint {
        case .prismatic, .weld, .filter: id = try createSlidingWeldFilter(descriptor, a: bodyA, b: b.bodyId, world: world)
        case .wheel, .motor: id = try createWheelMotor(descriptor, a: bodyA, b: b.bodyId, world: world)
        case .distance, .rope: id = try createDistance(descriptor, a: bodyA, b: b.bodyId, world: world)
        case .hinge, .worldHinge, .revolute: id = try createRevolute(descriptor, a: bodyA, b: b.bodyId, world: world)
        }
        guard b2Joint_IsValid(id) else { throw .nativeCreationFailed }
        return RuntimeJoint2D(world: world, descriptor: descriptor, id: id, bodyA: bodyA, bodyB: b.bodyId, ownedAnchor: ownedAnchor)
    }
}

/// Resolves late bodies and removes constraints when owners, components or attached bodies disappear.
@PlainSystem(dependencies: [.after(Physics2DSyncSystem.self)])
public struct PhysicsJoint2DSyncSystem {
    @Query<Entity, Ref<PhysicsJoint2DComponent>> private var joints
    @Res<Physics2DWorldHolder> private var physics
    public init(world _: World) {}

    @MainActor
    public func update(context: UpdateContext) {
        let world = physics.world
        world.seenJointOwners.removeAll(keepingCapacity: true)
        joints.forEach { entity, component in
            world.seenJointOwners.insert(entity.id)
            guard let (aID, bID) = RuntimeJoint2D.endpoints(component.jointDescriptor),
                let b = RuntimeJoint2D.body(context.world.getEntityByID(bID)) else {
                world.jointRecords.removeValue(forKey: entity.id)?.destroy()
                component.runtimeJoint = nil
                component.jointError = .missingBody
                return
            }
            let a = aID.flatMap { RuntimeJoint2D.body(context.world.getEntityByID($0)) }
            guard aID == nil || a != nil else {
                world.jointRecords.removeValue(forKey: entity.id)?.destroy()
                component.runtimeJoint = nil
                component.jointError = .missingBody
                return
            }
            if let record = world.jointRecords[entity.id], record.descriptor === component.jointDescriptor, record.matches(a: a, b: b) {
                component.runtimeJoint = record
                component.jointError = nil
                return
            }
            world.jointRecords.removeValue(forKey: entity.id)?.destroy()
            component.runtimeJoint = nil
            do throws(PhysicsJoint2DError) {
                let record = try RuntimeJoint2D.make(component.jointDescriptor, a: a, b: b, world: world)
                world.jointRecords[entity.id] = record
                component.runtimeJoint = record
                component.jointError = nil
            } catch {
                component.jointError = error
            }
        }
        world.retiredJointOwners.removeAll(keepingCapacity: true)
        for owner in world.jointRecords.keys where !world.seenJointOwners.contains(owner) { world.retiredJointOwners.append(owner) }
        for owner in world.retiredJointOwners { world.jointRecords.removeValue(forKey: owner)?.destroy() }
    }
}
