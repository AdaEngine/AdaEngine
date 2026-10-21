import AdaECS
import AdaTransform
import Math

@PlainSystem(dependencies: [.after(Physics2DWritebackSystem.self)])
public struct CharacterController2DSystem {
    @FilterQuery<Entity, Ref<CharacterController2DComponent>, Ref<Transform>, And<Without<PhysicsBody2DComponent>, Without<Collision2DComponent>>> private var characters
    @FilterQuery<Ref<CharacterController2DComponent>, Or<With<PhysicsBody2DComponent>, With<Collision2DComponent>>> private var conflicts
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
