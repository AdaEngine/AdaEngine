import AdaECS
import box2d
import Math

/// The main actor owns all joint mutations. Native lifetime is bounded by PhysicsWorld2D.
@MainActor
final class RuntimeJoint2D {
    weak var world: PhysicsWorld2D?
    let descriptor: PhysicsJoint2DDescriptor
    private(set) var id: b2JointId
    let bodyA: b2BodyId
    let bodyB: b2BodyId

    init(world: PhysicsWorld2D, descriptor: PhysicsJoint2DDescriptor, id: b2JointId, bodyA: b2BodyId, bodyB: b2BodyId) {
        self.world = world
        self.descriptor = descriptor
        self.id = id
        self.bodyA = bodyA
        self.bodyB = bodyB
    }
    var isConnected: Bool { world != nil && b2Joint_IsValid(id) }
    func destroy() {
        if isConnected { b2DestroyJoint(id) }
        id = b2_nullJointId
    }

    static func body(_ entity: Entity?) -> Body2D? {
        entity?.components[PhysicsBody2DComponent.self]?.runtimeBody ?? entity?.components[Collision2DComponent.self]?.runtimeBody
    }

    static func endpoints(_ descriptor: PhysicsJoint2DDescriptor) -> (Entity.ID, Entity.ID)? {
        switch descriptor.joint {
        case let .rope(a, b, _, _), let .distance(a, b, _): return (a, b)
        case .revolute: return nil
        }
    }

    static func make(_ descriptor: PhysicsJoint2DDescriptor, a: Body2D, b: Body2D, world: PhysicsWorld2D) throws(PhysicsJoint2DError) -> RuntimeJoint2D {
        guard b2StoreBodyId(a.bodyId) != b2StoreBodyId(b.bodyId), a.world === world, b.world === world,
            b2Body_GetType(a.bodyId) == b2_dynamicBody || b2Body_GetType(b.bodyId) == b2_dynamicBody else {
            throw PhysicsJoint2DError.invalidBodyPair
        }
        let settings: DistanceJoint2DSettings
        switch descriptor.joint {
        case let .distance(_, _, value): settings = value
        case let .rope(_, _, anchorA, anchorB):
            let start = b2Body_GetWorldPoint(a.bodyId, anchorA.b2Vec).asVector2
            let end = b2Body_GetWorldPoint(b.bodyId, anchorB.b2Vec).asVector2
            let length = max((end - start).squaredLength.squareRoot(), 0.005 * b2GetLengthUnitsPerMeter())
            settings = DistanceJoint2DSettings(length: length, frameA: .init(position: anchorA), frameB: .init(position: anchorB), limits: .init(lower: 0, upper: length))
        case .revolute: throw PhysicsJoint2DError.invalidSettings
        }
        try settings.validate()
        var definition = b2DefaultDistanceJointDef()
        definition.base.bodyIdA = a.bodyId
        definition.base.bodyIdB = b.bodyId
        definition.base.localFrameA = settings.frameA.native
        definition.base.localFrameB = settings.frameB.native
        definition.base.collideConnected = settings.collideConnected
        definition.length = settings.length
        // Box2D requires enableSpring for limits/motors; zero hertz disables the spring force.
        definition.enableSpring = settings.spring != nil || settings.limits != nil || settings.motor != nil
        definition.hertz = settings.spring?.hertz ?? 0
        definition.dampingRatio = settings.spring?.dampingRatio ?? 1
        definition.enableLimit = settings.limits != nil
        definition.minLength = settings.limits?.lower ?? settings.length
        definition.maxLength = settings.limits?.upper ?? settings.length
        definition.enableMotor = settings.motor != nil
        definition.motorSpeed = settings.motor?.speed ?? 0
        definition.maxMotorForce = settings.motor?.maximumEffort ?? 0
        let id = unsafe b2CreateDistanceJoint(world.worldId, &definition)
        guard b2Joint_IsValid(id) else { throw PhysicsJoint2DError.nativeCreationFailed }
        return RuntimeJoint2D(world: world, descriptor: descriptor, id: id, bodyA: a.bodyId, bodyB: b.bodyId)
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
                let a = RuntimeJoint2D.body(context.world.getEntityByID(aID)),
                let b = RuntimeJoint2D.body(context.world.getEntityByID(bID)) else {
                world.jointRecords.removeValue(forKey: entity.id)?.destroy()
                component.runtimeJoint = nil
                component.jointError = .missingBody
                return
            }
            if let record = world.jointRecords[entity.id], record.descriptor === component.jointDescriptor, record.isConnected,
                b2StoreBodyId(record.bodyA) == b2StoreBodyId(a.bodyId), b2StoreBodyId(record.bodyB) == b2StoreBodyId(b.bodyId) {
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
