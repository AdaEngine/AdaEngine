import AdaECS
import box2d
import Math

@MainActor
extension PhysicsWorld2D {
    /// Moves a virtual upright capsule using native planes and filtered convex sweeps.
    /// `position` is its bottom. It performs no body integration or dynamic pushing.
    public func moveCharacter(
        _ controller: inout CharacterController2DComponent,
        position: inout Vector2,
        deltaTime: Float,
        excluding owner: Entity.ID? = nil
    ) throws(CharacterController2DError) {
        let settings = controller.settings
        try settings.validate()
        guard deltaTime.isFinite, deltaTime > 0, position.x.isFinite, position.y.isFinite,
            controller.desiredVelocity.x.isFinite, controller.desiredVelocity.y.isFinite else { throw .invalidMotion }
        if controller.runtime?.world !== self || controller.runtime?.owner != owner || controller.runtime?.radius != settings.radius || controller.runtime?.height != settings.height {
            controller.runtime = CharacterRuntime2D(world: self, owner: owner, settings: settings)
            controller.lastPosition = nil
        }
        guard let runtime = controller.runtime else { throw .invalidMotion }
        if controller.resetMotion || controller.lastPosition != position {
            controller.horizontalVelocity = 0; controller.verticalVelocity = 0; controller.jumping = false
            controller.jumpRequested = false; controller.isGrounded = false; controller.resetMotion = false
        }
        let start = position
        let wasGrounded = controller.isGrounded
        let target = controller.desiredVelocity.x
        let acceleration = abs(target) > abs(controller.horizontalVelocity) ? settings.acceleration : settings.deceleration
        let change = max(-acceleration * deltaTime, min(acceleration * deltaTime, target - controller.horizontalVelocity))
        let horizontal = controller.horizontalVelocity + change
        let jumped = controller.jumpRequested && wasGrounded
        controller.jumpRequested = false
        if jumped { controller.verticalVelocity = settings.jumpSpeed; controller.jumping = true }
        controller.verticalVelocity = max(-settings.maximumFallSpeed, controller.verticalVelocity + gravity.y * settings.gravityScale * deltaTime)
        let vertical = controller.verticalVelocity
        var velocity = Vector2(horizontal, vertical)
        var remaining = velocity * deltaTime
        guard remaining.x.isFinite, remaining.y.isFinite else { throw .invalidMotion }
        var filter = b2DefaultQueryFilter()
        filter.categoryBits = controller.filter.categoryBitMask.rawValue
        filter.maskBits = controller.filter.collisionBitMask.rawValue
        let capsule = settings.capsule
        var blockedHorizontal = false
        for _ in 0..<4 {
            runtime.collide(position: position, capsule: capsule, filter: filter, horizontal: horizontal, minimumNormal: settings.minimumGroundNormalY)
            let solved = unsafe runtime.planes.withUnsafeMutableBufferPointer { unsafe b2SolvePlanes(remaining.b2Vec, $0.baseAddress, Int32($0.count)) }
            remaining = solved.delta.asVector2
            velocity = unsafe runtime.planes.withUnsafeBufferPointer { unsafe b2ClipVector(velocity.b2Vec, $0.baseAddress, Int32($0.count)) }.asVector2
            blockedHorizontal = blockedHorizontal || runtime.contacts.contains { $0.normal.y < settings.minimumGroundNormalY && $0.normal.x * horizontal < 0 }
            if remaining.squaredLength < 0.000000001 { break }
            let sweep = castCharacter(position: position, capsule: capsule, delta: remaining, filter: filter, owner: owner)
            position += remaining * sweep.fraction
            if let hit = sweep.hit {
                let inward = min(0, velocity.x * hit.normal.x + velocity.y * hit.normal.y)
                velocity -= hit.normal * inward
                blockedHorizontal = blockedHorizontal || (hit.normal.y < settings.minimumGroundNormalY && hit.normal.x * horizontal < 0)
            }
            remaining *= 1 - sweep.fraction
            if sweep.fraction == 1 { break }
        }
        if blockedHorizontal, !controller.jumping { velocity.y = min(velocity.y, max(0, vertical)) }
        controller.horizontalVelocity = blockedHorizontal ? velocity.x : horizontal
        controller.verticalVelocity = velocity.y
        if velocity.y <= 0 { controller.jumping = false }
        runtime.collide(position: position, capsule: capsule, filter: filter, horizontal: horizontal, minimumNormal: settings.minimumGroundNormalY)
        var ground = controller.jumping ? nil : runtime.ground(position: position, minimumNormal: settings.minimumGroundNormalY)
        if ground == nil, wasGrounded, !jumped, !controller.jumping, settings.groundSnapDistance > 0 {
            let delta = Vector2(0, -settings.groundSnapDistance)
            let sweep = castCharacter(position: position, capsule: capsule, delta: delta, filter: filter, owner: owner)
            if let hit = sweep.hit, hit.normal.y >= settings.minimumGroundNormalY {
                position += delta * sweep.fraction
                ground = hit
            }
        }
        controller.isGrounded = ground != nil
        controller.groundNormal = ground?.normal ?? .zero
        controller.groundPoint = ground?.point
        controller.groundEntityID = ground?.entity
        if ground != nil { controller.verticalVelocity = 0 }
        controller.velocity = (position - start) / deltaTime
        controller.lastError = nil
        controller.lastPosition = position
    }
}
