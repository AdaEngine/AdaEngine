//
//  Physics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/8/22.
//

@_implementationOnly import AdaBox2d
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
        let result = self.fixedTimestep.advance(with: context.deltaTime)
        
        let physicsBody = context.scene.performQuery(Self.physicsBodyQuery)
        let colissionBody = context.scene.performQuery(Self.collisionQuery)
        
        guard let world = context.scene.physicsWorld2D else {
            return
        }
        
        if result.isFixedTick {
            world.updateSimulation(result.fixedTime)
        }
        
        self.updatePhysicsBodyEntities(physicsBody, in: world)
        self.updateCollisionEntities(colissionBody, in: world)
    }
    
    // MARK: - Private
    
    private func updatePhysicsBodyEntities(_ entities: QueryResult, in world: PhysicsWorld2D) {
        entities.forEach { entity in
            var (physicsBody, transform) = entity.components[PhysicsBody2DComponent.self, Transform.self]

            if let body = physicsBody.runtimeBody {
                if physicsBody.mode == .static {
                    body.setTransform(
                        position: transform.position.xy,
                        angle: transform.position.z
                    )
                } else {
                    let position = body.getPosition()
                    transform.position.x = position.x
                    transform.position.y = position.y
                    transform.rotation = Quat(axis: [0, 0, 1], angle: body.getAngle())
                }
                
                body.massData.mass = physicsBody.massProperties.mass
            } else {
                var def = Body2DDefinition()
                def.position = transform.position.xy
                def.bodyMode = physicsBody.mode

                let body = world.createBody(definition: def, for: entity)
                physicsBody.runtimeBody = body

                for shapeResource in physicsBody.shapes {
                    let shape = self.makeShape(for: shapeResource, transform: transform)

                    var fixtureDef = b2_fixture_def()
                    fixtureDef.shape = UnsafeRawPointer(shape)

                    fixtureDef.density = physicsBody.material.density
                    fixtureDef.restitution = physicsBody.material.restitution
                    fixtureDef.friction = physicsBody.material.friction

                    body.addFixture(for: fixtureDef)
                    
                    shape.deallocate()
                }

                body.massData.mass = physicsBody.massProperties.mass
            }

            if let fixtureList = physicsBody.runtimeBody?.getFixtureList() {
                let collisionFilter = physicsBody.filter
                let filterData = fixtureList.filterData

                if !(filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                     filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {

                    var filter = b2_filter()
                    filter.categoryBits = collisionFilter.categoryBitMask.rawValue
                    filter.maskBits = collisionFilter.collisionBitMask.rawValue
                    fixtureList.filterData = filter
                }
            }
            
            entity.components += transform
            entity.components += physicsBody
        }
    }
    
    private func updateCollisionEntities(_ entities: QueryResult, in world: PhysicsWorld2D) {
        entities.forEach { entity in
            var (collisionBody, transform) = entity.components[Collision2DComponent.self, Transform.self]

            if let body = collisionBody.runtimeBody {
                body.setTransform(
                    position: transform.position.xy,
                    angle: transform.position.z
                )
            } else {
                var def = Body2DDefinition()
                def.position = transform.position.xy
                def.angle = transform.rotation.z
                def.bodyMode = .static

                let body = world.createBody(definition: def, for: entity)
                collisionBody.runtimeBody = body

                for shapeResource in collisionBody.shapes {
                    let shape = self.makeShape(for: shapeResource, transform: transform)
                    var fixtureDef = b2_fixture_def()
                    fixtureDef.shape = UnsafeRawPointer(shape)

                    if case .trigger = collisionBody.mode {
                        fixtureDef.isSensor = true
                    }

                    body.addFixture(for: fixtureDef)
                    
                    shape.deallocate()
                }
            }

            if let fixtureList = collisionBody.runtimeBody?.getFixtureList() {
                let collisionFilter = collisionBody.filter
                let filterData = fixtureList.filterData

                if !(filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                     filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {

                    var filter = b2_filter()
                    filter.categoryBits = collisionFilter.categoryBitMask.rawValue
                    filter.maskBits = collisionFilter.collisionBitMask.rawValue
                    fixtureList.filterData = filter
                }
            }

            entity.components += transform
            entity.components += collisionBody
        }
    }
    
    // MARK: - Helpers
    
    private func getBody(from entity: Entity) -> Body2D? {
        entity.components[PhysicsBody2DComponent.self]?.runtimeBody ??
        entity.components[Collision2DComponent.self]?.runtimeBody
    }
    
    private func makeShape(for shape: Shape2DResource, transform: Transform) -> OpaquePointer {
        switch shape.fixture {
        case .polygon(let shape):
            let shapeRef = b2_create_polygon_shape()!
            var points = unsafeBitCast(shape.verticies, to: [b2_vec2].self)
            b2_polygon_shape_set(shapeRef, &points, Int32(shape.verticies.count))
            return shapeRef
        case .circle(let shape):
            let shapeRef = b2_create_circle_shape()!
            b2_shape_set_radius(shapeRef, shape.radius * transform.scale.x)
            b2_circle_shape_set_position(shapeRef, shape.offset.b2Vec)
            return shapeRef
        case .box(let shape):
            let shapeRef = b2_create_polygon_shape()!
            b2_polygon_shape_set_as_box_with_center(
                shapeRef,
                transform.scale.x * shape.halfWidth, /* half width */
                transform.scale.y * shape.halfHeight, /* half height */
                shape.offset.b2Vec, /* center */
                0 /* angle */
            )
            
            return shapeRef
        }
    }
}
