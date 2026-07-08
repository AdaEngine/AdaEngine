//
//  Physics3DSystem.swift
//  AdaEngine
//
//  Created by Codex on 7/6/26.
//

import AdaECS
import AdaTransform
import box3d
import Math

@MainActor
@System
public func Physics3DUpdate(
    _ physicsWorld: Res<Physics3DWorldHolder>,
    _ fixedTime: Res<FixedTime>
) {
    let deltaTime = fixedTime.deltaTime
    let world = physicsWorld.world
    world.updateSimulation(deltaTime)
}

/// A system for simulating and updating physics bodies on the scene.
@PlainSystem
public struct Physics3DSyncSystem: Sendable {

    @Query<Entity, Ref<PhysicsBody3DComponent>, Ref<Transform>>
    private var physicsBodyQuery

    @Res<Physics3DWorldHolder>
    private var physicsWorld

    public init(world: World) { }

    public func update(context: UpdateContext) {
        self.syncPhysicsBodyEntities(in: physicsWorld.world)
    }

    // MARK: - Private

    private func syncPhysicsBodyEntities(in world: PhysicsWorld3D) {
        self.physicsBodyQuery.forEach { entity, physicsBody, transform in
            if let body = physicsBody.runtimeBody {
                if physicsBody.mode == .static {
                    body.setTransform(
                        position: transform.position,
                        rotation: transform.rotation
                    )
                }

                var massData = body.massData
                massData.mass = physicsBody.massProperties.mass
                body.massData = massData
            } else {
                var def = b3DefaultBodyDef()
                def.position = transform.position.b3Vec
                def.rotation = transform.rotation.b3Quat
                def.type = physicsBody.mode.b3Type

                let body = world.createBody(with: def, for: entity)
                physicsBody.runtimeBody = body

                for shapeResource in physicsBody.wrappedValue.shapes {
                    var shapeDef = b3DefaultShapeDef()
                    shapeDef.density = physicsBody.material.density
                    shapeDef.baseMaterial.restitution = physicsBody.material.restitution
                    shapeDef.baseMaterial.friction = physicsBody.material.friction

                    if physicsBody.wrappedValue.isTrigger {
                        shapeDef.isSensor = true
                    }

                    body.appendShape(
                        shapeResource,
                        shapeDef: shapeDef
                    )
                }

                var massData = body.massData
                massData.mass = physicsBody.massProperties.mass
                body.massData = massData
            }
        }
    }
}

/// A system for writing back simulated 3D physics state into scene components.
@PlainSystem
public struct Physics3DWritebackSystem: Sendable {

    @Query<Entity, Ref<PhysicsBody3DComponent>, Ref<Transform>>
    private var physicsBodyQuery

    public init(world: World) { }

    public func update(context: UpdateContext) {
        physicsBodyQuery.forEach { _, physicsBody, transform in
            guard
                physicsBody.mode != .static,
                let body = physicsBody.runtimeBody
            else {
                return
            }

            transform.position = body.getPosition()
            transform.rotation = body.getRotation()
        }
    }
}
