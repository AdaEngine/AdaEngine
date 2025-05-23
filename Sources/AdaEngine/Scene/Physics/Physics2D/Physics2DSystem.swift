//
//  Physics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/8/22.
//

import AdaECS
import box2d
import Math

// - TODO: (Vlad) Runtime update shape resource

/// A system for simulate and update physics bodies on the scene.
public final class Physics2DSystem: System, Sendable {
    
    private let fixedTimestep: FixedTimestep
    
    public init(world: World) {
        self.fixedTimestep = FixedTimestep(stepsPerSecond: Engine.shared.physicsTickPerSecond)
    }
    
    static let physicsBodyQuery = EntityQuery(
        where: .has(PhysicsBody2DComponent.self) && .has(Transform.self),
        filter: [.stored, .added]
    )
    
    static let collisionQuery = EntityQuery(
        where: .has(Collision2DComponent.self) && .has(Transform.self),
        filter: [.stored, .added]
    )
    
    static let jointsQuery = EntityQuery(
        where: .has(PhysicsJoint2DComponent.self) && .has(Transform.self)
    )
    
    public func update(context: UpdateContext) {
        let result = self.fixedTimestep.advance(with: context.deltaTime)
        let step = fixedTimestep.step

        context.scheduler.addTask { @MainActor in
            guard let world = context.world.physicsWorld2D else {
                return
            }
            
            if result.isFixedTick {
                world.updateSimulation(step)
                world.processContacts()
                world.processSensors()
            }

            let physicsBody = context.world.performQuery(Self.physicsBodyQuery)
            let colissionBody = context.world.performQuery(Self.collisionQuery)
            
            self.updatePhysicsBodyEntities(physicsBody, in: world)
            self.updateCollisionEntities(colissionBody, in: world)
        }
    }
    
    // MARK: - Private
    
    @MainActor
    private func updatePhysicsBodyEntities(_ entities: QueryResult, in world: PhysicsWorld2D) {
        for entity in entities {
            var (physicsBody, transform) = entity.components[PhysicsBody2DComponent.self, Transform.self]
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
                var def = b2DefaultBodyDef()
                def.fixedRotation = physicsBody.fixedRotation
                def.position = transform.position.xy.b2Vec
                def.type = physicsBody.mode.b2Type

                let body = world.createBody(with: def, for: entity)
                physicsBody.runtimeBody = body

                for shapeResource in physicsBody.shapes {
                    var shapeDef = b2DefaultShapeDef()
                    shapeDef.density = physicsBody.material.density
                    shapeDef.restitution = physicsBody.material.restitution
                    shapeDef.friction = physicsBody.material.friction
                    shapeDef.filter = physicsBody.filter.b2Filter
                    
                    if physicsBody.isTrigger {
                        shapeDef.isSensor = true
                    }
                    
                    if let debugColor = physicsBody.debugColor {
                        shapeDef.customColor = UInt32(debugColor.toHex)
                    }
                    
                    body.appendShape(
                        shapeResource,
                        transform: transform,
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
            entity.components += transform
            entity.components += physicsBody
        }
    }

    @MainActor
    private func updateCollisionEntities(_ entities: QueryResult, in world: PhysicsWorld2D) {
        for entity in entities {
            var (collisionBody, transform) = entity.components[Collision2DComponent.self, Transform.self]

            if let body = collisionBody.runtimeBody {
                if body.getPosition() != transform.position.xy {
                    body.setTransform(
                        position: transform.position.xy,
                        angle: transform.rotation.angle2D
                    )
                }
            } else {
                var def = b2DefaultBodyDef()
                def.position = transform.position.xy.b2Vec
                def.type = b2_staticBody

                let body = world.createBody(with: def, for: entity)
                collisionBody.runtimeBody = body

                for shapeResource in collisionBody.shapes {
                    var shapeDef = b2DefaultShapeDef()
                    shapeDef.density = 1
                    if let debugColor = collisionBody.debugColor {
                        shapeDef.customColor = UInt32(debugColor.toHex)
                    }
                    shapeDef.filter = collisionBody.filter.b2Filter
                    if case .trigger = collisionBody.mode {
                        shapeDef.isSensor = true
                    }
                    body.appendShape(
                        shapeResource,
                        transform: transform,
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

            entity.components += transform
            entity.components += collisionBody
        }
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func getBody(from entity: Entity) -> Body2D? {
        entity.components[PhysicsBody2DComponent.self]?.runtimeBody ??
        entity.components[Collision2DComponent.self]?.runtimeBody
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
