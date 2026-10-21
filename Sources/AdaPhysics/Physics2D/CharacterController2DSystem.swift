import AdaECS
import AdaTransform
import box2d
import Math

@PlainSystem(dependencies: [.after(Physics2DWritebackSystem.self)])
public struct CharacterController2DSystem {
    @FilterQuery<Entity, Ref<CharacterController2DComponent>, Ref<Transform>, And<Without<PhysicsBody2DComponent>, Without<Collision2DComponent>>> private var characters
    @FilterQuery<Ref<CharacterController2DComponent>, Or<With<PhysicsBody2DComponent>, With<Collision2DComponent>>> private var conflicts
    @PhysicsCoordinateWriteAccess2D private var coordinateWrites
    @PhysicsCoordinateAccess2D private var coordinateReads
    @Res<Physics2DWorldHolder> private var physics
    @Res<FixedTime?> private var time
    public init(world _: World) {}

    @MainActor
    public func update(context _: UpdateContext) {
        guard let time, time.deltaTime > 0 else {
            return
        }
        conflicts.forEach { controller in
            controller.lastError = .conflictingBody
            controller.velocity = .zero
            controller.isGrounded = false
            controller.groundNormal = .zero
            controller.groundPoint = nil
            controller.groundEntityID = nil
            controller.jumpRequested = false
        }
        characters.forEach { entity, controller, transform in
            guard entity.components[PhysicsPosition2DComponent.self]?.lastError == nil else {
                controller.lastError = .invalidMotion
                return
            }
            defer {
                if var coordinate = entity.components[PhysicsPosition2DComponent.self] {
                    if controller.mode == .dynamic, let body = controller.runtime?.body {
                        coordinate.position = PhysicsPosition2D(b2Body_GetPosition(body.bodyId))
                    } else {
                        coordinate.position = physics.world.coordinateOrigin.offset(by: transform.position.xy)
                    }
                    let projected = coordinate.position.displacement(from: physics.world.coordinateOrigin)
                    transform.position.x = projected.x; transform.position.y = projected.y
                    controller.lastPosition = projected
                    controller.lastGlobalPosition = coordinate.position
                    entity.components[PhysicsPosition2DComponent.self] = coordinate
                }
            }
            do throws(CharacterController2DError) {
                if controller.mode == .dynamic {
                    if let runtime = controller.runtime { try runtime.publish(&controller.wrappedValue, deltaTime: time.deltaTime) }
                    if let body = controller.runtime?.body {
                        let position = body.getPosition()
                        transform.position.x = position.x; transform.position.y = position.y
                        if let rotation = controller.runtime?.visualRotation { transform.rotation = rotation }
                    }
                    return
                }
                var position = transform.position.xy
                try physics.world.moveCharacter(&controller.wrappedValue, position: &position, deltaTime: time.deltaTime, excluding: entity.id)
                if position != transform.position.xy { transform.position.x = position.x; transform.position.y = position.y }
            } catch {
                controller.lastError = error
                controller.velocity = .zero
                controller.isGrounded = false
                controller.groundNormal = .zero
                controller.groundPoint = nil
                controller.groundEntityID = nil
                controller.jumpRequested = false
            }
        }
    }
}
