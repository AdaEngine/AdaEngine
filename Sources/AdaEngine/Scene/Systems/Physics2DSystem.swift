//
//  Physics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/8/22.
//

import box2d
import Math

// - TODO: (Vlad) Delete bodies if entity will delete physic component
// - TODO: (Vlad) Update system fixed times (Timer?)
// - TODO: (Vlad) Draw circles and polygons for debug
// - TODO: (Vlad) Joints
// - TODO: (Vlad) Runtime update shape resource
// - TODO: (Vlad) Debug render in other system?
final class Physics2DSystem: System {
    
    private var physicsFrame: Int = 0
    private var time: TimeInterval = 0
    
    // TODO: Should be modified
    private var physicsTicksPerSecond: Float = 60
    
    static let physicsBodyQuery = EntityQuery(
        where: .has(PhysicsBody2DComponent.self) && .has(Transform.self)
    )
    
    static let collisionQuery = EntityQuery(
        where: .has(Collision2DComponent.self) && .has(Transform.self)
    )
    
    static let jointsQuery = EntityQuery(
        where: .has(PhysicsJoint2DComponent.self) && .has(Transform.self)
    )
    
    unowned let world: PhysicsWorld2D
    
    required init(scene: Scene) {
        self.world = scene.physicsWorld2D
    }
    
    func update(context: UpdateContext) {
        let needDrawPolygons = context.scene.debugOptions.contains(.showPhysicsShapes) && context.scene.window != nil
        
        if needDrawPolygons {
            RenderEngine2D.shared.beginContext(for: context.scene.window!.id, camera: context.scene.activeCamera)
        }
        
        let physicsBody = context.scene.performQuery(Self.physicsBodyQuery)
        let colissionBody = context.scene.performQuery(Self.collisionQuery)
        let joints = context.scene.performQuery(Self.jointsQuery)

        self.updatePhysicsBodyEntities(physicsBody, needDrawPolygons: needDrawPolygons, context: context)
        self.updateCollisionEntities(colissionBody, needDrawPolygons: needDrawPolygons, context: context)
        self.updateJointsEntities(joints, needDrawPolygons: needDrawPolygons, context: context)
        
        self.world.updateSimulation(context.deltaTime)
        
        if needDrawPolygons {
            RenderEngine2D.shared.commitContext()
        }
    }
    
    // MARK: - Private
    
    private func updatePhysicsBodyEntities(_ entities: QueryResult, needDrawPolygons: Bool, context: UpdateContext) {
        for entity in entities {
            var (physicsBody, transform) = entity.components[PhysicsBody2DComponent.self, Transform.self]
            
            if let body = physicsBody.runtimeBody {
                transform.position.x = body.ref.position.x
                transform.position.y = body.ref.position.y
//                transform.rotation = body.ref.angle
            } else {
                var def = Body2DDefinition()
                def.position = [transform.position.x, transform.position.y]
                def.angle = transform.rotation.z
                def.bodyMode = physicsBody.mode
                
                let body = self.world.createBody(definition: def, for: entity)
                physicsBody.runtimeBody = body
                
                for shape in physicsBody.shapes {
                    shape.fixtureDef.density = physicsBody.material.density
                    shape.fixtureDef.restitution = physicsBody.material.restitution
                    shape.fixtureDef.friction = physicsBody.material.friction
                    body.addFixture(for: shape)
                }
            }
            
            if let fixtureList = physicsBody.runtimeBody?.ref.getFixtureList() {
                let collisionFilter = physicsBody.filter
                if !(fixtureList.filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                     fixtureList.filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {
                    
                    var filter = b2Filter()
                    filter.categoryBits = collisionFilter.categoryBitMask.rawValue
                    filter.maskBits = collisionFilter.collisionBitMask.rawValue
                    fixtureList.setFilterData(filter)
                }
            }
            
            if let body = physicsBody.runtimeBody?.ref, needDrawPolygons {
                self.drawDebug(
                    body: body,
                    transform: transform.matrix,
                    color: context.scene.debugPhysicsColor
                )
            }
            
            entity.components += transform
            entity.components += physicsBody
        }
    }
    
    private func updateCollisionEntities(_ entities: QueryResult, needDrawPolygons: Bool, context: UpdateContext) {
        for entity in entities {
            var (collisionBody, transform) = entity.components[Collision2DComponent.self, Transform.self]
            
            if let body = collisionBody.runtimeBody {
                transform.position.x = body.ref.position.x
                transform.position.y = body.ref.position.y
                
                transform.rotation.z = body.ref.angle
            } else {
                var def = Body2DDefinition()
                def.position = [transform.position.x, transform.position.y]
                def.angle = transform.rotation.z
                def.bodyMode = .static
                
                let body = world.createBody(definition: def, for: entity)
                collisionBody.runtimeBody = body
                
                for shape in collisionBody.shapes {
                    
                    if case .trigger = collisionBody.mode {
                        shape.fixtureDef.isSensor = true
                    }
                    
                    body.addFixture(for: shape)
                }
            }
            
            if let fixtureList = collisionBody.runtimeBody?.ref.getFixtureList() {
                let collisionFilter = collisionBody.filter
                
                if !(fixtureList.filterData.categoryBits == collisionFilter.categoryBitMask.rawValue &&
                     fixtureList.filterData.maskBits == collisionFilter.collisionBitMask.rawValue) {
                    
                    var filter = b2Filter()
                    filter.categoryBits = collisionFilter.categoryBitMask.rawValue
                    filter.maskBits = collisionFilter.collisionBitMask.rawValue
                    fixtureList.setFilterData(filter)
                }
            }
            
            if let body = collisionBody.runtimeBody?.ref, needDrawPolygons {
                self.drawDebug(
                    body: body,
                    transform: transform.matrix,
                    color: context.scene.debugPhysicsColor
                )
            }
            
            entity.components += transform
            entity.components += collisionBody
        }
    }
    
    private func updateJointsEntities(_ entities: QueryResult, needDrawPolygons: Bool, context: UpdateContext) {
        for entity in entities {
            var (jointComponent, transform) = entity.components[PhysicsJoint2DComponent.self, Transform.self]
            
            if jointComponent.runtimeJoint == nil {
                switch jointComponent.jointDescriptor.joint {
                case .rope(let entityA, let entityB, let vectorA, let vectorB):
                    let joint = b2RopeJointDef()
                    guard
                        let bodyA = self.getBody(from: entityA)?.ref,
                        let bodyB = self.getBody(from: entityB)?.ref
                    else {
                        continue
                    }
                    
                    joint.bodyA = bodyA
                    joint.bodyB = bodyB
                    let ref = self.world.createJoint(joint)
                    jointComponent.runtimeJoint = ref
                case .revolute(let entityA):
                    guard
                        let bodyA = self.getBody(from: entityA)?.ref,
                        let current = self.getBody(from: entity)?.ref
                    else {
                        continue
                    }
                    
                    let anchor = transform.position.xy.b2Vec
                    let joint = b2RevoluteJointDef(bodyA: bodyA, bodyB: current, anchor: anchor)
                    
                    let ref = self.world.createJoint(joint)
                    jointComponent.runtimeJoint = ref
                }
            }
            
            entity.components += jointComponent
        }
    }
    
    private func getBody(from entity: Entity) -> Body2D? {
        entity.components[PhysicsBody2DComponent.self]?.runtimeBody ??
        entity.components[Collision2DComponent.self]?.runtimeBody
    }
    
    // MARK: - Debug draw
    
    // FIXME: Use body transform instead
    private func drawDebug(body: b2Body, transform: Transform3D, color: Color) {
        guard let fixture = body.getFixtureList() else { return }
        
        switch fixture.shape.type {
        case .circle:
            self.drawCircle(transform: transform, color: color)
        case .polygon:
            self.drawQuad(transform: transform, color: color)
        default:
            return
        }
    }
    
    private func drawCircle(transform: Transform3D, color: Color) {
        RenderEngine2D.shared.drawCircle(
            transform: transform,
            thickness: 0.1,
            fade: 0,
            color: color
        )
    }
    
    private func drawQuad(transform: Transform3D, color: Color) {
        RenderEngine2D.shared.drawQuad(transform: transform, color: color)
    }
    
    private func drawMesh(transform: Transform3D, color: Color) {
        // TODO: Draw 2d mesh here
    }
}
