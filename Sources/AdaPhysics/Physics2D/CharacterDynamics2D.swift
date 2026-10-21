import AdaECS
import box2d
import Math

public enum CharacterController2DMode: String, Codable, Sendable { case query, `dynamic` }

/// Bounded physical character drive/support. Native collision remains enabled between support bodies.
public struct CharacterController2DDynamics: Codable, Equatable, Sendable {
    public var mass: Float = 1
    public var maximumDriveForce: Float = 1000
    public var maximumSupportForce: Float = 1000
    public var maximumTensionForce: Float = 0
    public var spring = JointSpring2D(hertz: 4)
    public init() {}
    func validate() throws(CharacterController2DError) {
        guard mass.isFinite, mass > 0, maximumDriveForce.isFinite, maximumDriveForce >= 0,
            maximumSupportForce.isFinite, maximumSupportForce >= 0, maximumTensionForce.isFinite,
            maximumTensionForce >= 0, spring.isValid else { throw .invalidConfiguration }
    }
}

extension CharacterRuntime2D {
    func clearDrive() {
        if world != nil {
            if b2Joint_IsValid(pogo) { b2DestroyJoint(pogo) }
            if b2Joint_IsValid(mover) { b2DestroyJoint(mover) }
        }
        pogo = b2_nullJointId; mover = b2_nullJointId
    }

    func destroy() {
        clearDrive()
        if let world {
            if b2Body_IsValid(airAnchor) { b2DestroyBody(airAnchor) }
            if let body { world.destroyBody(body) }
        }
        airAnchor = b2_nullBodyId
        body = nil
    }

    func createBody(entity: Entity, position: Vector2, controller: CharacterController2DComponent) throws(CharacterController2DError) {
        guard let world, position.x.isFinite, position.y.isFinite else { throw .invalidMotion }
        var definition = unsafe b2DefaultBodyDef()
        unsafe definition.type = b2_dynamicBody
        unsafe definition.position = position.b2Position
        unsafe definition.motionLocks.angularZ = true
        unsafe definition.enableSleep = false
        unsafe definition.enableContactRecycling = false
        unsafe definition.gravityScale = controller.settings.gravityScale
        let body = unsafe world.createBody(with: definition, for: entity)
        self.body = body
        var shape = unsafe b2DefaultShapeDef()
        unsafe shape.material.friction = 0
        unsafe shape.filter = controller.filter.b2Filter
        unsafe shape.enableContactEvents = true
        unsafe shape.enableSensorEvents = true
        unsafe shape.enableHitEvents = true
        unsafe shape.enableCustomFiltering = true
        unsafe shape.enablePreSolveEvents = true
        var capsule = controller.settings.capsule
        capsule.radius = radius
        shapeID = unsafe b2CreateCapsuleShape(body.bodyId, &shape, &capsule)
        guard b2Shape_IsValid(shapeID) else { destroy(); throw .invalidConfiguration }
        var anchor = unsafe b2DefaultBodyDef()
        airAnchor = unsafe b2CreateBody(world.worldId, &anchor)
        updateBodySettings(controller)
    }

    func updateBodySettings(_ controller: CharacterController2DComponent) {
        guard let body else {
            return
        }
        var mass = body.massData
        if mass.mass != controller.dynamics.mass {
            mass.mass = controller.dynamics.mass
            mass.rotationalInertia = 0
            body.massData = mass
        }
        body.gravityScale = controller.settings.gravityScale
        let filter = b2Shape_GetFilter(shapeID)
        if filter.categoryBits != controller.filter.categoryBitMask.rawValue || filter.maskBits != controller.filter.collisionBitMask.rawValue {
            b2Shape_SetFilter(shapeID, controller.filter.b2Filter)
        }
    }

    func support(_ controller: inout CharacterController2DComponent, position: Vector2, velocityY: Float) -> CharacterGround2D? {
        guard let world else {
            return nil
        }
        let settings = controller.settings
        var filter = b2DefaultQueryFilter()
        filter.categoryBits = controller.filter.categoryBitMask.rawValue
        filter.maskBits = controller.filter.collisionBitMask.rawValue
        var geometry = settings
        geometry.radius = radius; geometry.height = height
        let capsule = geometry.capsule
        collide(position: position, capsule: capsule, filter: filter, horizontal: 0, minimumNormal: settings.minimumGroundNormalY)
        var ground = self.ground(position: position, minimumNormal: settings.minimumGroundNormalY)
        if ground == nil, settings.groundSnapDistance > 0 {
            let sweep = world.castCharacter(position: position, capsule: capsule, delta: [0, -settings.groundSnapDistance], filter: filter, owner: owner)
            if let hit = sweep.hit, hit.normal.y >= settings.minimumGroundNormalY { ground = hit }
        }
        if controller.jumping {
            let floorY = ground.map { b2Body_GetWorldPointVelocity($0.body, $0.point.b2Position).y } ?? 0
            if ground != nil && velocityY - floorY > 0.1 {
                return nil
            }
            if ground != nil || velocityY <= 0 { controller.jumping = false } else {
            return nil
        }
        }
        return ground
    }

    func control(_ controller: inout CharacterController2DComponent, deltaTime: Float) throws(CharacterController2DError) {
        guard let world, let body, b2Body_IsValid(body.bodyId), controller.desiredVelocity.x.isFinite,
            controller.desiredVelocity.y.isFinite else { throw .invalidMotion }
        try controller.settings.validate()
        try controller.dynamics.validate()
        var velocity = body.getLinearVelocity()
        var ground = support(&controller, position: body.getPosition(), velocityY: velocity.y)
        if controller.jumpRequested, let floor = ground {
            velocity.y = controller.settings.jumpSpeed + b2Body_GetWorldPointVelocity(floor.body, floor.point.b2Position).y
            body.setLinearVelocity(velocity)
            controller.jumping = true
            ground = nil
        }
        controller.jumpRequested = false
        var target = controller.desiredVelocity.x
        if contacts.contains(where: { $0.normal.y > 0 && $0.normal.y < controller.settings.minimumGroundNormalY && $0.normal.x * target < 0 }) { target = 0 }
        let a = ground?.body ?? airAnchor
        let floorVelocity = b2Body_GetLinearVelocity(a)
        if let ground { target += b2Body_GetWorldPointVelocity(a, ground.point.b2Position).x - floorVelocity.x }
        let accelerating = abs(target) > abs(velocity.x - floorVelocity.x)
        let acceleration = accelerating ? controller.settings.acceleration : controller.settings.deceleration
        let force = min(controller.dynamics.maximumDriveForce, controller.dynamics.mass * acceleration)
        if !b2Joint_IsValid(mover) || b2StoreBodyId(b2Joint_GetBodyA(mover)) != b2StoreBodyId(a) {
            if b2Joint_IsValid(mover) { b2DestroyJoint(mover) }
            var definition = unsafe b2DefaultMoverJointDef()
            unsafe definition.base.bodyIdA = a
            unsafe definition.base.bodyIdB = body.bodyId
            unsafe definition.base.collideConnected = true
            mover = unsafe b2CreateMoverJoint(world.worldId, &definition)
        }
        b2MoverJoint_SetLinearVelocity(mover, b2Vec2(x: target, y: 0))
        b2MoverJoint_SetMaxVelocityForce(mover, b2Vec2(x: force, y: 0))
        var impulse: Float = 0
        var speed: Float = 0
        if b2Joint_IsValid(pogo) {
            if let ground, b2StoreBodyId(b2Joint_GetBodyA(pogo)) == b2StoreBodyId(ground.body) {
                let substep = deltaTime / Float(max(1, world.substepIterations))
                impulse = b2PogoJoint_GetImpulse(pogo) * deltaTime / lastDeltaTime
                impulse = max(-controller.dynamics.maximumTensionForce * substep, min(controller.dynamics.maximumSupportForce * substep, impulse))
                speed = b2PogoJoint_GetCurrentSpeed(pogo)
            }
            b2DestroyJoint(pogo)
            pogo = b2_nullJointId
        }
        if let ground {
            var definition = unsafe b2DefaultPogoJointDef()
            unsafe definition.base.bodyIdA = ground.body
            unsafe definition.base.bodyIdB = body.bodyId
            unsafe definition.base.collideConnected = true
            unsafe definition.base.localFrameA = JointFrame2D(position: b2Body_GetLocalPoint(ground.body, ground.point.b2Position).asVector2).native
            unsafe definition.base.localFrameB = JointFrame2D(position: [0, height * 0.5]).native
            unsafe definition.normal = ground.normal.b2Vec
            unsafe definition.restLength = height * 0.5 - radius + (radius + controller.settings.skinWidth) * ground.normal.y
            unsafe definition.hertz = controller.dynamics.spring.hertz
            unsafe definition.dampingRatio = controller.dynamics.spring.dampingRatio
            unsafe definition.maxCompressionForce = controller.dynamics.maximumSupportForce
            unsafe definition.maxTensionForce = controller.dynamics.maximumTensionForce
            unsafe definition.impulse = impulse
            unsafe definition.velocity = speed
            pogo = unsafe b2CreatePogoJoint(world.worldId, &definition)
        }
        lastDeltaTime = deltaTime
        controller.lastError = nil
    }

    func publish(_ controller: inout CharacterController2DComponent, deltaTime: Float) throws(CharacterController2DError) {
        try controller.settings.validate()
        try controller.dynamics.validate()
        guard let body, b2Body_IsValid(body.bodyId) else {
            return
        }
        let position = body.getPosition()
        var velocity = body.getLinearVelocity()
        if velocity.y < -controller.settings.maximumFallSpeed {
            velocity.y = -controller.settings.maximumFallSpeed
            body.setLinearVelocity(velocity)
        }
        let ground = support(&controller, position: position, velocityY: velocity.y)
        controller.isGrounded = ground != nil
        controller.groundNormal = ground?.normal ?? .zero
        controller.groundPoint = ground?.point
        controller.groundEntityID = ground?.entity
        controller.velocity = controller.lastPosition.map { (position - $0) / deltaTime } ?? velocity
        controller.lastPosition = position
    }
}
