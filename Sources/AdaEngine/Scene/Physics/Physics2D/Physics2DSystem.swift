//
//  Physics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/8/22.
//

@_implementationOnly import box2d
import Math

// - TODO: (Vlad) Runtime update shape resource

/// A system for simulate and update physics bodies on the scene.
public final class Physics2DSystem: System {
    
    let fixedTimestep: FixedTimestep
    
    public init(scene: Scene) {
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
        preconditionMainThreadOnly()
        
        let result = self.fixedTimestep.advance(with: context.deltaTime)
        
        let physicsBody = context.scene.performQuery(Self.physicsBodyQuery)
        let colissionBody = context.scene.performQuery(Self.collisionQuery)
        
        guard let world = context.scene.physicsWorld2D else {
            return
        }
        
        if result.isFixedTick {
            world.updateSimulation(result.fixedTime)
            world.processContacts()
        }
        
        self.updatePhysicsBodyEntities(physicsBody, in: world)
        self.updateCollisionEntities(colissionBody, in: world)
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
                        angle: Angle.radians(transform.position.z)
                    )
                } else {
                    let position = body.getPosition()
                    transform.position.x = position.x
                    transform.position.y = position.y
                    transform.rotation = Quat(axis: [0, 0, 1], angle: body.getAngle().radians)
                }
                
                body.massData.mass = physicsBody.massProperties.mass
            } else {
                var def = b2DefaultBodyDef()
                def.position = transform.position.xy.b2Vec
                def.type = physicsBody.mode.b2Type

                let body = world.createBody(with: def, for: entity)
                physicsBody.runtimeBody = body

                for shapeResource in physicsBody.shapes {
                    let polygon = BoxShape2D.makeB2Polygon(for: shapeResource, transform: transform)
                    var shapeDef = b2DefaultShapeDef()
                    shapeDef.density = physicsBody.material.density
                    shapeDef.restitution = physicsBody.material.restitution
                    shapeDef.friction = physicsBody.material.friction

                    body.appendPolygonShape(polygon, shapeDef: shapeDef)
                }

                body.massData.mass = physicsBody.massProperties.mass
            }

            if let shapes = physicsBody.runtimeBody?.getShapes() {
                let collisionFilter = physicsBody.filter

                for shape in shapes {
                    let filterData = shape.filter

                    if !(filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                         filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {

                        var filter = b2Filter()
                        filter.categoryBits = collisionFilter.categoryBitMask.rawValue
                        filter.maskBits = collisionFilter.collisionBitMask.rawValue
                        shape.filter = filter
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
                body.setTransform(
                    position: transform.position.xy,
                    angle: Angle.radians(transform.position.z)
                )
            } else {
                var def = b2DefaultBodyDef()
                def.position = transform.position.xy.b2Vec
                def.rotation = b2MakeRot(transform.rotation.z)
                def.type = b2_staticBody

                let body = world.createBody(with: def, for: entity)
                collisionBody.runtimeBody = body

                for shapeResource in collisionBody.shapes {
                    let shape = BoxShape2D.makeB2Polygon(for: shapeResource, transform: transform)
                    var shapeDef = b2DefaultShapeDef()
                    if case .trigger = collisionBody.mode {
                        shapeDef.isSensor = true
                    }
                    body.appendPolygonShape(shape, shapeDef: shapeDef)
                }
            }

            if let shapes = collisionBody.runtimeBody?.getShapes() {
                let collisionFilter = collisionBody.filter

                for shape in shapes {
                    let filterData = shape.filter

                    if !(filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                         filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {

                        var filter = b2Filter()
                        filter.categoryBits = collisionFilter.categoryBitMask.rawValue
                        filter.maskBits = collisionFilter.collisionBitMask.rawValue
                        shape.filter = filter
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
