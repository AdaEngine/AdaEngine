//
//  DebugPhysics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/26/23.
//

import Foundation

struct DebugPhysics2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(Physics2DSystem.self)]
//
//    static let entities = EntityQuery(
//        where: .has(PhysicsBody2DComponent.self) || .has(Collision2DComponent.self) || .has(PhysicsJoint2DComponent.self),
//        filter: .removed
//    )
    
    static let cameras = EntityQuery(where:
            .has(Camera.self) &&
            .has(VisibleEntities.self) &&
            .has(RenderItems<Transparent2DRenderItem>.self)
    )
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        guard context.scene.debugOptions.contains(.showPhysicsShapes) else {
            return
        }
        
        context.scene.performQuery(Self.cameras).forEach { entity in
            var (camera, visibleEntities, renderItems) = entity.components[Camera.self, VisibleEntities.self, RenderItems<Transparent2DRenderItem>.self]
            
            if !camera.isActive {
                return
            }
            
            self.draw(
                scene: context.scene,
                visibleEntities: visibleEntities.entities,
                renderItems: &renderItems
            )
            
            entity.components += renderItems
        }
    }
    
    private func draw(scene: Scene, visibleEntities: [Entity], renderItems: inout RenderItems<Transparent2DRenderItem>) {
        
    }
    
    // MARK: - Debug draw
    
    // FIXME: Use body transform instead
    private func drawDebug(
        context: Renderer2D.DrawContext?,
        body: Body2D,
        transform: Transform,
        color: Color
    ) {
//        guard let fixtureList = body.getFixtureList(), let context = context else { return }
//
//        var nextFixture: b2Fixture? = fixtureList
//
//        while let fixture = nextFixture {
//            switch fixture.shape.type {
//            case .circle:
//                self.drawCircle(
//                    context: context,
//                    position: body.position.asVector2,
//                    angle: body.angle,
//                    radius: fixture.shape.radius,
//                    color: color
//                )
//            case .polygon:
//                self.drawQuad(
//                    context: context,
//                    position: body.position.asVector2,
//                    angle: body.angle,
//                    size: transform.scale.xy,
//                    color: color
//                )
//            default:
//                continue
//            }
//
//            nextFixture = fixture.getNext()
//        }
    }
    
    private func drawCircle(context: Renderer2D.DrawContext, position: Vector2, angle: Float, radius: Float, color: Color) {
        context.drawCircle(
            position: Vector3(position, 0),
            rotation: [0, 0, angle], // FIXME: (Vlad) We should set rotation angle
            radius: radius,
            thickness: 0.1,
            fade: 0,
            color: color
        )
    }
    
    private func drawQuad(context: Renderer2D.DrawContext, position: Vector2, angle: Float, size: Vector2, color: Color) {
        context.drawQuad(position: Vector3(position, 1), size: size, color: color.opacity(0.2))
        
//        context.drawLine(
//            start: [(position.x - size.x) / 2, (position.y - size.y) / 2, 0],
//            end: [(position.x + size.x) / 2, (position.y - size.y) / 2, 0],
//            color: color
//        )
//
//        context.drawLine(
//            start: [(position.x + size.x) / 2, (position.y - size.y) / 2, 0],
//            end: [(position.x + size.x) / 2, (position.y + size.y) / 2, 0],
//            color: color
//        )
//
//        context.drawLine(
//            start: [(position.x + size.x) / 2, (position.y + size.y) / 2, 0],
//            end: [(position.x - size.x) / 2, (position.y - size.y) / 2, 0],
//            color: color
//        )
//
//        context.drawLine(
//            start: [(position.x - size.x) / 2, (position.y - size.y) / 2, 0],
//            end: [(position.x - size.x) / 2 , (position.y + size.y) / 2, 0],
//            color: color
//        )
//
//        context.drawLine(
//            start: [(position.x - size.x) / 2 , (position.y + size.y) / 2, 0],
//            end: [(position.x + size.x) / 2, (position.y + size.y) / 2, 0],
//            color: color
//        )
    }
}
