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

                    var fixtureDef = b2FixtureDef()
                    fixtureDef.shape = UnsafeRawPointer(shape).assumingMemoryBound(to: b2Shape.self).pointee

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

                    var filter = b2Filter()
                    filter.categoryBits = collisionFilter.categoryBitMask.rawValue
                    filter.maskBits = collisionFilter.collisionBitMask.rawValue
                    fixtureList.filterData = filter
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
                    var fixtureDef = b2FixtureDef()
                    fixtureDef.shape = UnsafeRawPointer(shape).assumingMemoryBound(to: b2Shape.self).pointee

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

                    var filter = b2Filter()
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
    
    @MainActor
    private func getBody(from entity: Entity) -> Body2D? {
        entity.components[PhysicsBody2DComponent.self]?.runtimeBody ??
        entity.components[Collision2DComponent.self]?.runtimeBody
    }
    
    private func makeShape(for shape: Shape2DResource, transform: Transform) -> OpaquePointer {
        switch shape.fixture {
        case .polygon(let shape):
            let shapeRef = UnsafeMutablePointer<b2PolygonShape>.allocate(capacity: 1)
            shapeRef.initialize(to: b2PolygonShape.Create())
            shape.verticies.withUnsafeBytes { ptr in
                let baseAddress = ptr.assumingMemoryBound(to: b2Vec2.self).baseAddress
                shapeRef.pointee.Set(baseAddress, int32(shape.verticies.count))
            }
            
            return OpaquePointer(shapeRef)
        case .circle(let shape):
            let shapeRef = UnsafeMutablePointer<b2CircleShape>.allocate(capacity: 1)
            shapeRef.initialize(to: b2CircleShape.Create())
            shapeRef.pointee.m_radius = shape.radius * transform.scale.x
            shapeRef.pointee.m_p = shape.offset.b2Vec
            return OpaquePointer(shapeRef)
        case .box(let shape):
            let shapeRef = UnsafeMutablePointer<b2PolygonShape>.allocate(capacity: 1)
            shapeRef.initialize(to: b2PolygonShape.Create())
            shapeRef.pointee.SetAsBox(
                transform.scale.x * shape.halfWidth, /* half width */
                transform.scale.y * shape.halfHeight,  /* half height */
                shape.offset.b2Vec, /* center */
                0 /* angle */
            )
            
            return OpaquePointer(shapeRef)
        }
    }
}
