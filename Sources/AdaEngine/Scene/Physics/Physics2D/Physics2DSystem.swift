//
//  Physics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/8/22.
//

import AdaBox2d
import Math

// - TODO: (Vlad) Draw polygons for debug
// - TODO: (Vlad) Runtime update shape resource
// - TODO: (Vlad) Debug render in other system?
final class Physics2DSystem: System {
    
    let fixedTimestep: FixedTimestep
    
    init(scene: Scene) {
        self.fixedTimestep = FixedTimestep(stepsPerSecond: Engine.shared.physicsTickPerSecond)
    }
    
    static let physicsBodyQuery = EntityQuery(
        where: .has(PhysicsBody2DComponent.self) && .has(Transform.self)
    )
    
    static let collisionQuery = EntityQuery(
        where: .has(Collision2DComponent.self) && .has(Transform.self)
    )
    
    static let jointsQuery = EntityQuery(
        where: .has(PhysicsJoint2DComponent.self) && .has(Transform.self)
    )
    
    static let physicsWorld = EntityQuery(
        where: .has(Physics2DWorldComponent.self)
    )
    
    static let removedEntities = EntityQuery(
        where: .has(PhysicsBody2DComponent.self) || .has(Collision2DComponent.self) || .has(PhysicsJoint2DComponent.self),
        filter: .removed
    )
    
    func update(context: UpdateContext) {
        let result = self.fixedTimestep.advance(with: context.deltaTime)
        
        let physicsBody = context.scene.performQuery(Self.physicsBodyQuery)
        let colissionBody = context.scene.performQuery(Self.collisionQuery)
        let joints = context.scene.performQuery(Self.jointsQuery)
        let removedEntities = context.scene.performQuery(Self.removedEntities)
        
        // We should have only one physics world
        let worlds = context.scene.performQuery(Self.physicsWorld)
        
        guard let world = worlds.first?.components[Physics2DWorldComponent.self]?.world else {
            return
        }
        
        if result.isFixedTick {
            world.updateSimulation(result.fixedTime)
        }

        self.updatePhysicsBodyEntities(physicsBody, in: world)
        
        self.updateCollisionEntities(colissionBody, in: world)
        
        self.updateJointsEntities(joints, scene: context.scene, in: world)
        
        self.removePhysicsBodiesInRemovedEntities(removedEntities, world: world)
    }
    
    // MARK: - Private
    
    private func updatePhysicsBodyEntities(_ entities: QueryResult, in world: PhysicsWorld2D) {
        for entity in entities {
            var (physicsBody, transform) = entity.components[PhysicsBody2DComponent.self, Transform.self]
            
            if let body = physicsBody.runtimeBody {
                let position = body.getPosition()
                transform.position.x = position.x
                transform.position.y = position.y
                transform.rotation = Quat(axis: [0, 0, 1], angle: body.getAngle())
            } else {
                var def = Body2DDefinition()
                def.position = transform.position.xy
                def.bodyMode = physicsBody.mode
                
                let body = world.createBody(definition: def, for: entity)
                physicsBody.runtimeBody = body
                
                for shapeResource in physicsBody.shapes {
                    let shape = self.makeShape(for: shapeResource, transform: transform)

                    var fixtureDef = b2FixtureDef()
                    fixtureDef.shape = shape

                    fixtureDef.density = physicsBody.material.density
                    fixtureDef.restitution = physicsBody.material.restitution
                    fixtureDef.friction = physicsBody.material.friction

                    body.addFixture(for: &fixtureDef)
                }
                
                var massData = body.ref.GetMassData()
                massData.mass = physicsBody.massProperties.mass
                body.ref.SetMassData(&massData)
            }
            
            if let fixtureList = physicsBody.runtimeBody?.getFixtureList() {
                let collisionFilter = physicsBody.filter
                let filterData = fixtureList.GetFilterData().pointee

                if !(filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                     filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {

                    var filter = b2Filter()
                    filter.categoryBits = collisionFilter.categoryBitMask.rawValue
                    filter.maskBits = collisionFilter.collisionBitMask.rawValue
                    fixtureList.SetFilterData(filter)
                }
            }
            
            entity.components += transform
            entity.components += physicsBody
        }
    }
    
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
                    fixtureDef.shape = shape
                    
                    if case .trigger = collisionBody.mode {
                        fixtureDef.isSensor = true
                    }
                    
                    body.addFixture(for: &fixtureDef)
                }
            }
            
            if let fixtureList = collisionBody.runtimeBody?.getFixtureList() {
                let collisionFilter = collisionBody.filter
                let filterData = fixtureList.GetFilterData().pointee
                
                if !(filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                     filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {
                    
                    var filter = b2Filter()
                    filter.categoryBits = collisionFilter.categoryBitMask.rawValue
                    filter.maskBits = collisionFilter.collisionBitMask.rawValue
                    fixtureList.SetFilterData(filter)
                }
            }
            
            entity.components += transform
            entity.components += collisionBody
        }
    }
    
    private func updateJointsEntities(_ entities: QueryResult, scene: Scene, in world: PhysicsWorld2D) {
        for entity in entities {
            var (jointComponent, transform) = entity.components[PhysicsJoint2DComponent.self, Transform.self]

            if jointComponent.runtimeJoint == nil {
                switch jointComponent.jointDescriptor.joint {
                case .rope(let entityAId, let entityBId, _, _):
                    var joint = b2JointDef()
                    guard
                        let entityA = scene.world.getEntityByID(entityAId),
                        let entityB = scene.world.getEntityByID(entityBId),
                        let bodyA = self.getBody(from: entityA)?.ref,
                        let bodyB = self.getBody(from: entityB)?.ref
                    else {
                        continue
                    }
                    joint.type = e_pulleyJoint
                    joint.bodyA = bodyA
                    joint.bodyB = bodyB

                    let ref = world.createJoint(&joint)
                    jointComponent.runtimeJoint = ref
                case .revolute(let entityAId):
                    guard
                        let entityA = scene.world.getEntityByID(entityAId),
                        let bodyA = self.getBody(from: entityA)?.ref,
                        let current = self.getBody(from: entity)?.ref
                    else {
                        continue
                    }

                    let anchor = transform.position.xy.b2Vec
                    var joint = b2RevoluteJointDef()
                    joint.Initialize(bodyA, current, anchor)

                    let jointRef = ada.b2JointDef_unsafeCast(&joint)!
                    let ref = world.createJoint(jointRef)
                    jointComponent.runtimeJoint = ref
                }
            }

            entity.components += jointComponent
        }
    }
    
    private func removePhysicsBodiesInRemovedEntities(_ entities: QueryResult, world: PhysicsWorld2D) {
        entities.forEach { entity in
            guard let body = self.getBody(from: entity) else { return }
            world.destroyBody(body)
        }
    }
    
    // MARK: - Helpers
    
    private func getBody(from entity: Entity) -> Body2D? {
        entity.components[PhysicsBody2DComponent.self]?.runtimeBody ??
        entity.components[Collision2DComponent.self]?.runtimeBody
    }
    
    var allocator = b2BlockAllocator()
    
    private func makeShape(for shape: Shape2DResource, transform: Transform) -> b2Shape {
        switch shape.fixture {
        case .polygon(let shape):
            let polygon = ada.b2PolygonShape_create()!
            var points = unsafeBitCast(shape.verticies, to: [b2Vec2].self)
            polygon.Set(&points, int32(shape.verticies.count))

            defer {
                ada.b2Polygon_delete(polygon)
            }

            return polygon.Clone(&allocator)
        case .circle(let shape):
            var circle = ada.b2CircleShape_create()!
//            circle.m_radius = shape.radius * transform.scale.x
            circle.m_p = shape.offset.b2Vec

            defer {
                ada.b2CircleShape_delete(circle)
            }

            return circle.Clone(&allocator)
        case .box(let shape):
            let polygon = ada.b2PolygonShape_create()!

            polygon.SetAsBox(
                transform.scale.x * shape.halfWidth,
                transform.scale.y * shape.halfHeight,
                shape.offset.b2Vec,
                0
            )

            defer {
                ada.b2Polygon_delete(polygon)
            }

            return polygon.Clone(&allocator)
        }
    }
}
