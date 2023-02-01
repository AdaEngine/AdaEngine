//
//  Physics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/8/22.
//

// - FIXME: (Vlad) Move to c++ version instead of swift.
import box2d
import Math

// - TODO: (Vlad) Update system fixed times (Timer?)
// - TODO: (Vlad) Draw polygons for debug
// - TODO: (Vlad) Runtime update shape resource
// - TODO: (Vlad) Debug render in other system?
final class Physics2DSystem: System {
    
    init(scene: Scene) { }
    
    private var physicsFrame: Int = 0
    private var time: TimeInterval = 0
    
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
    
    // I think it should be smth like scene renderer here.
    private let render2D = RenderEngine2D()
    
    func update(context: UpdateContext) {
        let needDrawPolygons = context.scene.debugOptions.contains(.showPhysicsShapes) && context.scene.viewport != nil
        
        var drawContext: RenderEngine2D.DrawContext?
        
        if needDrawPolygons {
            drawContext = self.render2D.beginContext(for: context.scene.activeCamera)
            drawContext?.setDebugName("Physics 2D Debug")
        }
        
        let physicsBody = context.scene.performQuery(Self.physicsBodyQuery)
        let colissionBody = context.scene.performQuery(Self.collisionQuery)
        let joints = context.scene.performQuery(Self.jointsQuery)
        
        let removedEntities = context.scene.performQuery(Self.removedEntities)
        
        // We should have only one physics world
        let worlds = context.scene.performQuery(Self.physicsWorld)
        
        guard let world = worlds.first?.components[Physics2DWorldComponent.self]?.world else {
            return
        }
        
        world.updateSimulation(context.deltaTime)

        self.updatePhysicsBodyEntities(
            physicsBody,
            world: world,
            needDrawPolygons: needDrawPolygons,
            context: context,
            drawContext: drawContext
        )
        
        self.updateCollisionEntities(
            colissionBody,
            world: world,
            needDrawPolygons: needDrawPolygons,
            context: context,
            drawContext: drawContext
        )
        
        self.updateJointsEntities(
            joints,
            world: world,
            needDrawPolygons: needDrawPolygons,
            context: context
        )
        
        if needDrawPolygons {
            drawContext?.commitContext()
        }
        
        self.removePhysicsBodiesInRemovedEntities(removedEntities, world: world)
    }
    
    // MARK: - Private
    
    private func updatePhysicsBodyEntities(
        _ entities: QueryResult,
        world: PhysicsWorld2D,
        needDrawPolygons: Bool,
        context: UpdateContext,
        drawContext: RenderEngine2D.DrawContext?
    ) {
        for entity in entities {
            var (physicsBody, transform) = entity.components[PhysicsBody2DComponent.self, Transform.self]
            
            if let body = physicsBody.runtimeBody {
                transform.position.x = body.ref.position.x
                transform.position.y = body.ref.position.y
                transform.rotation = Quat(axis: [0, 0, 1], angle: body.ref.angle)
            } else {
                var def = Body2DDefinition()
                def.position = transform.position.xy
                def.bodyMode = physicsBody.mode
                
                let body = world.createBody(definition: def, for: entity)
                physicsBody.runtimeBody = body
                
                for shapeResource in physicsBody.shapes {
                    
                    let shape = self.makeShape(for: shapeResource, transform: transform)
                    
                    let fixtureDef = b2FixtureDef()
                    fixtureDef.shape = shape
                    
                    fixtureDef.density = physicsBody.material.density
                    fixtureDef.restitution = physicsBody.material.restitution
                    fixtureDef.friction = physicsBody.material.friction
                    
                    body.addFixture(for: fixtureDef)
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
                    context: drawContext,
                    body: body,
                    transform: transform,
                    color: context.scene.debugPhysicsColor
                )
            }
            
            entity.components += transform
            entity.components += physicsBody
        }
    }
    
    private func updateCollisionEntities(
        _ entities: QueryResult,
        world: PhysicsWorld2D,
        needDrawPolygons: Bool,
        context: UpdateContext,
        drawContext: RenderEngine2D.DrawContext?
    ) {
        for entity in entities {
            var (collisionBody, transform) = entity.components[Collision2DComponent.self, Transform.self]
            
            if let body = collisionBody.runtimeBody {
                
                body.ref.setTransform(
                    position: transform.position.xy.b2Vec,
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
                    
                    let fixtureDef = b2FixtureDef()
                    fixtureDef.shape = shape
                    
                    if case .trigger = collisionBody.mode {
                        fixtureDef.isSensor = true
                    }
                    
                    body.addFixture(for: fixtureDef)
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
                    context: drawContext,
                    body: body,
                    transform: transform,
                    color: context.scene.debugPhysicsColor
                )
            }
            
            entity.components += transform
            entity.components += collisionBody
        }
    }
    
    private func updateJointsEntities(
        _ entities: QueryResult,
        world: PhysicsWorld2D,
        needDrawPolygons: Bool,
        context: UpdateContext
    ) {
        for entity in entities {
            var (jointComponent, transform) = entity.components[PhysicsJoint2DComponent.self, Transform.self]
            
            if jointComponent.runtimeJoint == nil {
                switch jointComponent.jointDescriptor.joint {
                case .rope(let entityAId, let entityBId, _, _):
                    
                    let joint = b2RopeJointDef()
                    guard
                        let entityA = context.scene.world.getEntityByID(entityAId),
                        let entityB = context.scene.world.getEntityByID(entityBId),
                        let bodyA = self.getBody(from: entityA)?.ref,
                        let bodyB = self.getBody(from: entityB)?.ref
                    else {
                        continue
                    }
                    
                    joint.bodyA = bodyA
                    joint.bodyB = bodyB
                    let ref = world.createJoint(joint)
                    jointComponent.runtimeJoint = ref
                case .revolute(let entityAId):
                    guard
                        let entityA = context.scene.world.getEntityByID(entityAId),
                        let bodyA = self.getBody(from: entityA)?.ref,
                        let current = self.getBody(from: entity)?.ref
                    else {
                        continue
                    }
                    
                    let anchor = transform.position.xy.b2Vec
                    let joint = b2RevoluteJointDef(bodyA: bodyA, bodyB: current, anchor: anchor)
                    
                    let ref = world.createJoint(joint)
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
    
    private func makeShape(for shape: Shape2DResource, transform: Transform) -> b2Shape {
        switch shape.fixture {
        case .polygon(let shape):
            let polygon = b2PolygonShape()
            polygon.set(vertices: unsafeBitCast(shape.verticies, to: [b2Vec2].self))
            return polygon
        case .circle(let shape):
            let circle = b2CircleShape()
            circle.radius = shape.radius * transform.scale.x
            circle.p = shape.offset.b2Vec
            return circle
        case .box(let shape):
            let polygon = b2PolygonShape()
            polygon.setAsBox(
                halfWidth: transform.scale.x * shape.halfWidth,
                halfHeight: transform.scale.y * shape.halfHeight,
                center: shape.offset.b2Vec,
                angle: 0
            )
            
            return polygon
        }
    }
    
    // MARK: - Debug draw
    
    // FIXME: Use body transform instead
    private func drawDebug(
        context: RenderEngine2D.DrawContext?,
        body: b2Body,
        transform: Transform,
        color: Color
    ) {
        guard let fixtureList = body.getFixtureList(), let context = context else { return }
        
        var nextFixture: b2Fixture? = fixtureList
        
        while let fixture = nextFixture {
            switch fixture.shape.type {
            case .circle:
                self.drawCircle(
                    context: context,
                    position: body.position.asVector2,
                    angle: body.angle,
                    radius: fixture.shape.radius,
                    color: color
                )
            case .polygon:
                self.drawQuad(
                    context: context,
                    position: body.position.asVector2,
                    angle: body.angle,
                    size: transform.scale.xy,
                    color: color
                )
            default:
                continue
            }
            
            nextFixture = fixture.getNext()
        }
    }
    
    private func drawCircle(context: RenderEngine2D.DrawContext, position: Vector2, angle: Float, radius: Float, color: Color) {
        context.drawCircle(
            position: Vector3(position, 0),
            rotation: [0, 0, 0], // FIXME: (Vlad) We should set rotation angle
            radius: radius,
            thickness: 0.1,
            fade: 0,
            color: color
        )
    }
    
    private func drawQuad(context: RenderEngine2D.DrawContext, position: Vector2, angle: Float, size: Vector2, color: Color) {
        context.drawQuad(position: Vector3(position, 1), size: size, color: color.opacity(0.2))
        
//        render2D.drawLine(
//            start: [(position.x - size.x) / 2, (position.y - size.y) / 2, 0],
//            end: [(position.x + size.x) / 2, (position.y - size.y) / 2, 0],
//            color: color
//        )
//
//        render2D.drawLine(
//            start: [(position.x + size.x) / 2, (position.y - size.y) / 2, 0],
//            end: [(position.x + size.x) / 2, (position.y + size.y) / 2, 0],
//            color: color
//        )
//
//        render2D.drawLine(
//            start: [(position.x + size.x) / 2, (position.y + size.y) / 2, 0],
//            end: [(position.x - size.x) / 2, (position.y - size.y) / 2, 0],
//            color: color
//        )
//
//        render2D.drawLine(
//            start: [(position.x - size.x) / 2, (position.y - size.y) / 2, 0],
//            end: [(position.x - size.x) / 2 , (position.y + size.y) / 2, 0],
//            color: color
//        )
//
//        render2D.drawLine(
//            start: [(position.x - size.x) / 2 , (position.y + size.y) / 2, 0],
//            end: [(position.x + size.x) / 2, (position.y + size.y) / 2, 0],
//            color: color
//        )
    }
}
