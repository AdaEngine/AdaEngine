//
//  Physics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/8/22.
//

import box2d

class Physics2DSystem: System {
    
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
    
    let world: PhysicsWorld2D
    
    required init(scene: Scene) {
        self.world = scene.physicsWorld2D
    }
    
    func update(context: UpdateContext) {
        
        let needDrawPolygons = context.scene.debugOptions.contains(.showPhysicsShapes)
        
        if needDrawPolygons {
            RenderEngine2D.shared.flush()
            RenderEngine2D.shared.setTriangleFillMode(.lines)
        }
        
        let physicsBody = context.scene.performQuery(Self.physicsBodyQuery)
        let colissionBody = context.scene.performQuery(Self.collisionQuery)

        self.updatePhysicsBodyEntities(physicsBody, needDrawPolygons: needDrawPolygons, context: context)
        
        self.updateCollisionEntities(colissionBody, needDrawPolygons: needDrawPolygons, context: context)
        
        self.world.updateSimulation(context.deltaTime)
        
        if needDrawPolygons {
            RenderEngine2D.shared.flush()
            RenderEngine2D.shared.setTriangleFillMode(.fill)
        }
    }
    
    private func updatePhysicsBodyEntities(_ entities: QueryResult, needDrawPolygons: Bool, context: UpdateContext) {
        for entity in entities {
            var (physicsBody, transform) = entity.components[PhysicsBody2DComponent.self, Transform.self]
            
            if let body = physicsBody.runtimeBody {
                transform.position.x = body.ref.position.x
                transform.position.y = body.ref.position.y
            } else {
                var def = Body2DDefinition()
                def.position = [transform.position.x, transform.position.y]
                def.angle = transform.rotation.z
                def.bodyMode = physicsBody.mode
                
                let body = self.world.createBody(definition: def, for: entity)
                physicsBody.runtimeBody = body
                
                for shape in physicsBody.shapes {
                    shape.fixtureDef.density = physicsBody.density
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
            
            if needDrawPolygons {
                RenderEngine2D.shared.drawQuad(
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
                def.bodyMode = collisionBody.mode
                
                let body = world.createBody(definition: def, for: entity)
                collisionBody.runtimeBody = body
                
                for shape in collisionBody.shapes {
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
            
            if needDrawPolygons {
                RenderEngine2D.shared.drawQuad(
                    transform: transform.matrix,
                    color: context.scene.debugPhysicsColor
                )
            }
            
            entity.components += transform
            entity.components += collisionBody
        }
    }
}
