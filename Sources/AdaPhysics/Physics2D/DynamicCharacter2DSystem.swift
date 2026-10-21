import AdaECS
import AdaTransform
import box2d
import Math

/// Owns native character bodies/joints independently of copied component values.
@PlainSystem(dependencies: [.after(Physics2DSyncSystem.self)])
public struct DynamicCharacter2DSyncSystem {
    @FilterQuery<Entity, Ref<CharacterController2DComponent>, Ref<Transform>, And<Without<PhysicsBody2DComponent>, Without<Collision2DComponent>>> private var characters
    @PhysicsCoordinateAccess2D private var coordinates
    @Res<Physics2DWorldHolder> private var physics
    public init(world _: World) {}

    @MainActor
    public func update(context _: UpdateContext) {
        let world = physics.world
        world.seenCharacters.removeAll(keepingCapacity: true)
        characters.forEach { entity, controller, transform in
            guard controller.mode == .dynamic else {
            return
        }
            guard entity.components[PhysicsPosition2DComponent.self]?.lastError == nil else {
                controller.lastError = .invalidMotion
                controller.runtime = nil
                return
            }
            world.seenCharacters.insert(entity.id)
            do throws(CharacterController2DError) {
                try controller.settings.validate()
                try controller.dynamics.validate()
                guard transform.position.x.isFinite, transform.position.y.isFinite else { throw .invalidMotion }
                if let record = world.characterRecords[entity.id], record === controller.runtime,
                    record.radius == controller.settings.radius, record.height == controller.settings.height,
                    let body = record.body, b2Body_IsValid(body.bodyId), b2Shape_IsValid(record.shapeID) {
                    record.updateBodySettings(controller.wrappedValue)
                    if controller.resetMotion || controller.lastPosition != transform.position.xy {
                        record.clearDrive()
                        if let position = world.authoredPosition(entity, fallback: transform.position.xy) {
                            b2Body_SetTransform(body.bodyId, position, b2MakeRot(0))
                        }
                        body.setLinearVelocity(.zero)
                        controller.lastPosition = transform.position.xy
                        controller.jumping = false; controller.jumpRequested = false; controller.resetMotion = false
                    }
                    record.visualRotation = transform.rotation
                    return
                }
                world.characterRecords.removeValue(forKey: entity.id)?.destroy()
                let record = CharacterRuntime2D(world: world, owner: entity.id, settings: controller.settings, mode: .dynamic)
                try record.createBody(entity: entity, position: transform.position.xy, controller: controller.wrappedValue)
                record.visualRotation = transform.rotation
                world.characterRecords[entity.id] = record
                controller.runtime = record
                controller.lastPosition = transform.position.xy
                if controller.resetMotion { controller.jumpRequested = false }
                controller.resetMotion = false
                controller.jumping = false; controller.velocity = .zero; controller.isGrounded = false
                controller.lastError = nil
            } catch {
                world.characterRecords.removeValue(forKey: entity.id)?.destroy()
                controller.runtime = nil
                controller.lastError = error
                controller.isGrounded = false
            }
        }
        world.retiredCharacters.removeAll(keepingCapacity: true)
        for id in world.characterRecords.keys where !world.seenCharacters.contains(id) { world.retiredCharacters.append(id) }
        for id in world.retiredCharacters { world.characterRecords.removeValue(forKey: id)?.destroy() }
    }
}

@PlainSystem
public struct DynamicCharacter2DControlSystem {
    public static var dependencies: [SystemDependency] { [.before(Physics2DUpdateSystem.self)] }
    @Res<Physics2DWorldHolder> private var physics
    @FilterQuery<Ref<CharacterController2DComponent>, And<Without<PhysicsBody2DComponent>, Without<Collision2DComponent>>> private var characters
    @Res<FixedTime?> private var time
    public init(world _: World) {}

    @MainActor
    public func update(context _: UpdateContext) {
        guard let time, time.deltaTime > 0 else {
            return
        }
        characters.forEach { controller in
            guard controller.mode == .dynamic, let runtime = controller.runtime, runtime.world === physics.world, runtime.body != nil else {
            return
        }
            do throws(CharacterController2DError) {
                try runtime.control(&controller.wrappedValue, deltaTime: time.deltaTime)
            } catch {
                runtime.clearDrive()
                controller.lastError = error
                controller.jumpRequested = false
            }
        }
    }
}
