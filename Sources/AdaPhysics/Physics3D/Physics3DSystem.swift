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
        self.updatePhysicsBodyEntities(in: physicsWorld.world)
    }

    // MARK: - Private

    private func updatePhysicsBodyEntities(in world: PhysicsWorld3D) {
        self.physicsBodyQuery.forEach { entity, physicsBody, transform in
            if let body = physicsBody.runtimeBody {
                if physicsBody.mode == .static {
                    body.setTransform(
                        position: transform.position,
                        rotation: transform.rotation
                    )
                } else {
                    transform.position = body.getPosition()
                    transform.rotation = body.getRotation()
                }
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
            }
        }
    }
}
