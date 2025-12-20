//
//  Physics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/8/22.
//

import AdaECS
import AdaTransform
import AdaUtils
import box2d
import Math

// - TODO: (Vlad) Runtime update shape resource

/// A system for simulate and update physics bodies on the scene.
@PlainSystem
public struct Physics2DSystem: Sendable {

    public init(world: World) { }

    @Query<Entity, Ref<PhysicsBody2DComponent>, Ref<Transform>>
    private var physicsBodyQuery
    
    @Query<Entity, Ref<Collision2DComponent>, Ref<Transform>>
    private var collisionQuery
    
    @Query<Entity, Ref<PhysicsJoint2DComponent>, Ref<Transform>>
    private var jointsQuery
    
    @Res<Physics2DWorldHolder>
    private var physicsWorld

    @Res<FixedTime>
    private var fixedTime

    @MainActor
    public func update(context: UpdateContext) {
        let deltaTime = fixedTime.deltaTime
        let world = self.physicsWorld.world
        world.updateSimulation(deltaTime)
        world.processContacts()
        world.processSensors()
        self.updatePhysicsBodyEntities(in: world)
        self.updateCollisionEntities(in: world)
    }
    
    // MARK: - Private
    
    @MainActor
    private func updatePhysicsBodyEntities(in world: PhysicsWorld2D) {
        self.physicsBodyQuery.forEach { (entity, physicsBody, transform) in
            if let body = physicsBody.runtimeBody {
                if physicsBody.mode == .static {
                    body.setTransform(
                        position: transform.position.xy,
                        angle: transform.rotation.angle2D
                    )
                } else {
                    let position = body.getPosition()
                    transform.position.x = position.x
                    transform.position.y = position.y
                    transform.rotation = Quat(axis: [0, 0, 1], angle: -body.getAngle().radians)
                }
                
                body.massData.mass = physicsBody.massProperties.mass
            } else {
                var def = unsafe b2DefaultBodyDef()
                unsafe def.fixedRotation = physicsBody.fixedRotation
                unsafe def.position = transform.position.xy.b2Vec
                unsafe def.type = physicsBody.mode.b2Type

                let body = unsafe world.createBody(with: def, for: entity)
                physicsBody.runtimeBody = body

                for shapeResource in physicsBody.wrappedValue.shapes {
                    var shapeDef = unsafe b2DefaultShapeDef()
                    unsafe shapeDef.density = physicsBody.material.density
                    unsafe shapeDef.restitution = physicsBody.material.restitution
                    unsafe shapeDef.friction = physicsBody.material.friction
                    unsafe shapeDef.filter = physicsBody.filter.b2Filter

                    if physicsBody.wrappedValue.isTrigger {
                        unsafe shapeDef.isSensor = true
                    }
                    
                    if let debugColor = physicsBody.debugColor {
                        unsafe shapeDef.customColor = UInt32(debugColor.toHex)
                    }
                    
                    unsafe body.appendShape(
                        shapeResource,
                        transform: transform.wrappedValue,
                        shapeDef: shapeDef
                    )
                }

                body.massData.mass = physicsBody.massProperties.mass
            }

            if let shapes = physicsBody.runtimeBody?.getShapes() {
                let collisionFilter = physicsBody.filter

                for shape in shapes {
                    let filterData = shape.filter

                    if !(filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                         filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {
                        shape.filter = collisionFilter.b2Filter
                    }
                }
            }
        }
    }

    @MainActor
    private func updateCollisionEntities(in world: PhysicsWorld2D) {
        collisionQuery.forEach { (entity, collisionBody, transform) in
            if let body = collisionBody.runtimeBody {
                if body.getPosition() != transform.position.xy {
                    body.setTransform(
                        position: transform.position.xy,
                        angle: transform.rotation.angle2D
                    )
                }
            } else {
                var def = unsafe b2DefaultBodyDef()
                unsafe def.position = transform.position.xy.b2Vec
                unsafe def.type = b2_staticBody

                let body = unsafe world.createBody(with: def, for: entity)
                collisionBody.runtimeBody = body

                for shapeResource in collisionBody.wrappedValue.shapes {
                    var shapeDef = unsafe b2DefaultShapeDef()
                    unsafe shapeDef.density = 1
                    if let debugColor = collisionBody.debugColor {
                        unsafe shapeDef.customColor = UInt32(debugColor.toHex)
                    }
                    unsafe shapeDef.filter = collisionBody.filter.b2Filter
                    if case .trigger = collisionBody.mode {
                        unsafe shapeDef.isSensor = true
                    }
                    unsafe body.appendShape(
                        shapeResource,
                        transform: transform.wrappedValue,
                        shapeDef: shapeDef
                    )
                }
            }

            if let shapes = collisionBody.runtimeBody?.getShapes() {
                let collisionFilter = collisionBody.filter

                for shape in shapes {
                    let filterData = shape.filter

                    if !(filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                         filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {
                        shape.filter = collisionFilter.b2Filter
                    }
                }
            }
        }
    }
}

private extension CollisionFilter {
    var b2Filter: b2Filter {
        var filter = b2DefaultFilter()
        filter.categoryBits = categoryBitMask.rawValue
        filter.maskBits = collisionBitMask.rawValue
        return filter
    }
}

private extension Quat {
    var angle2D: Angle {
        let rads = Math.atan2(
            2 * (self.w * self.z + self.x * self.y),
            1 - 2 * (self.y * self.y + self.z * self.z)
        )
        return Angle.radians(rads)
    }
}
