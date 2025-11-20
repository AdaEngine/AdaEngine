//
//  DebugPhysics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/26/23.
//

import AdaECS
import AdaUtils
import AdaTransform
import box2d
import Math
@_spi(Internal) import AdaRender

public struct PhysicsDebugOptions: OptionSet, Resource {
    public var rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    /// Draw physics collision shapes for physics object.
    public static let showPhysicsShapes = PhysicsDebugOptions(rawValue: 1 << 0)

    public static let showBoundingBoxes = PhysicsDebugOptions(rawValue: 1 << 1)
}

@Component
struct ExctractedPhysicsMesh2DDebug {
    let entityId: Entity.ID
    let mesh: Mesh
    let material: Material
    let transform: Transform3D
}

/// System for exctracting physics bodies for debug rendering.
@PlainSystem
public struct DebugPhysicsExctract2DSystem {

    @EntityQuery(
        where: (.has(PhysicsBody2DComponent.self) || .has(Collision2DComponent.self) || .has(PhysicsJoint2DComponent.self)) && .has(Visibility.self)
    )
    private var entities

    @Query<Camera, GlobalTransform>
    private var cameras

    public init(world: World) { }

    @MainActor
    public func update(context: inout UpdateContext) {
        guard let (camera, globalTransform) = self.cameras.first else {
            return
        }

        let world = context.world
        guard world.getResource(PhysicsDebugOptions.self)?.contains(.showPhysicsShapes) == true else {
            return
        }

        guard let world = world.physicsWorld2D else {
            return
        }

        //            guard let window = scene?.window else {
        //                return
        //            }
        //
        //            var graphics = UIGraphicsContext(window: window)
        //            graphics.beginDraw(in: window.frame.size, scaleFactor: 1)
        //
        //            if let viewUniform = camera.components[GlobalViewUniform.self] {
        //                let viewMatrix = viewUniform.viewProjectionMatrix
        //                graphics.concatenate(viewMatrix)
        //                graphics.scaleBy(x: window.frame.size.width / 2, y: window.frame.size.height / 2)
        //                graphics.translateBy(x: window.frame.size.width / 2, y: -window.frame.size.height / 2)
        //            }
        //
        //            let drawContext = WorldDebugDrawContext()
        //            var debugDraw = b2DefaultDebugDraw()
        //            debugDraw.DrawSolidPolygon = DebugPhysicsExctract2DSystem_DrawSolidPolygon
        //            debugDraw.DrawSolidCircle = DebugPhysicsExctract2DSystem_DrawSolidCircle
        //            debugDraw.context = Unmanaged.passUnretained(drawContext).toOpaque()
        //            debugDraw.drawShapes = true
        //            debugDraw.drawAABBs = true
        //            world.debugDraw(with: debugDraw)
        //
        //            drawContext.forEach { item in
        //                switch item {
        //                case let .line(start, end, color):
        //                    graphics.drawLine(
        //                        start: start,
        //                        end: end,
        //                        lineWidth: 2.0,
        //                        color: color
        //                    )
        //                case let .circle(center, radius, color):
        //                    graphics.drawEllipse(
        //                        in: Rect(
        //                            x: center.x - radius,
        //                            y: -center.y - radius,
        //                            width: radius * 2,
        //                            height: radius * 2
        //                        ),
        //                        color: color,
        //                        thickness: 0.1
        //                    )
        //                }
        //            }
        //
        //            graphics.commitDraw()
    }

    @MainActor
    private func getRuntimeBody(from entity: Entity) -> Body2D? {
        return entity.components[PhysicsBody2DComponent.self]?.runtimeBody
        ?? entity.components[Collision2DComponent.self]?.runtimeBody
    }
}

///// Draw a solid capsule.
//void ( *DrawSolidCapsule )( b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context );

///// Draw a line segment.
//void ( *DrawSegment )( b2Vec2 p1, b2Vec2 p2, b2HexColor color, void* context );
//
///// Draw a string in world space
//void ( *DrawString )( b2Vec2 p, const char* s, b2HexColor color, void* context );

private final class WorldDebugDrawContext {

    enum DebugItem {
        case line(start: Vector2, end: Vector2, color: Color)
        case circle(center: Vector2, radius: Float, color: Color)
    }

    private var drawStack: [DebugItem] = []

    func addLine(start: Vector2, end: Vector2, color: Color) {
        self.drawStack.append(.line(start: start, end: end, color: color))
    }

    func addCircle(center: Vector2, radius: Float, color: Color) {
        self.drawStack.append(.circle(center: center, radius: radius, color: color))
    }

    func forEach(_ block: (DebugItem) -> Void) {
        self.drawStack.forEach(block)
    }
}

private func DebugPhysicsExctract2DSystem_DrawSolidCircle(
    _ transform: b2Transform,
    _ radius: Float,
    _ color: b2HexColor,
    _ context: UnsafeMutableRawPointer?
) {
    let debugContext = Unmanaged<WorldDebugDrawContext>
        .fromOpaque(context!)
        .takeUnretainedValue()

    let color = Color.fromHex(Int(color.rawValue))

    let center = Vector2(transform.p.x, transform.p.y)

    debugContext.addCircle(center: center, radius: radius, color: color)

    let direction = Vector2(
        transform.q.c * radius,  // cos(angle) * radius
        transform.q.s * radius   // sin(angle) * radius
    )

    let start = center
    let end = center + direction

    debugContext.addLine(start: start, end: end, color: color)
}

private func DebugPhysicsExctract2DSystem_DrawSolidPolygon(
    _ transform: b2Transform,
    _ verticies: UnsafePointer<b2Vec2>?,
    _ vertexCount: Int32,
    _ radius: Float,
    _ color: b2HexColor,
    _ context: UnsafeMutableRawPointer?
) {
    guard let verticies else {
        return
    }

    let debugContext = Unmanaged<WorldDebugDrawContext>
        .fromOpaque(context!)
        .takeUnretainedValue()
    let color = Color.fromHex(Int(color.rawValue))

    let vertices = (0..<vertexCount).map { index in
        let vertex = verticies[Int(index)]
        return Vector2(vertex.x, vertex.y)
    }

    for i in 0..<vertexCount {
        let start = vertices[Int(i)]
        let end = vertices[Int((Int(i) + 1) % Int(vertexCount))]

        let startTransformed = Vector2(
            transform.q.c * start.x - transform.q.s * start.y + transform.p.x,
            transform.q.s * start.x + transform.q.c * start.y + transform.p.y
        )

        let endTransformed = Vector2(
            transform.q.c * end.x - transform.q.s * end.y + transform.p.x,
            transform.q.s * end.x + transform.q.c * end.y + transform.p.y
        )

        debugContext.addLine(start: startTransformed, end: endTransformed, color: color)
    }
}

/// System for rendering debug physics shape on top of the scene.
@PlainSystem
public struct Physics2DDebugDrawSystem: Sendable {

    @Query<VisibleEntities, Ref<RenderItems<Transparent2DRenderItem>>>
    private var cameras

    @Query<ExctractedPhysicsMesh2DDebug>
    private var meshes

    //    @Res
    //    private var meshDrawPass: Mesh2DDrawPass?

    public init(world: World) {}

    public func update(context: inout UpdateContext) {

        //        self.cameras.forEach { visibleEntities, renderItems in
        //            self.draw(
        //                visibleEntities: visibleEntities,
        //                items: &renderItems.wrappedValue.items
        //            )
        //        }
        //    }
        //
        //    private func draw(
        //        visibleEntities: VisibleEntities,
        //        items: inout [Transparent2DRenderItem]
        //    ) {
        //    itemIterator:
        //        for item in self.meshes {
        //            if !visibleEntities.entityIds.contains(item.entityId) {
        //                continue
        //            }
        //
        //            let uniform = Mesh2DUniform(
        //                model: item.transform,
        //                modelInverseTranspose: .identity
        //            )
        //
        //            for model in item.mesh.models {
        //                for part in model.parts {
        //                    guard let pipeline = item.material.getOrCreatePipeline(for: part.vertexDescriptor, keys: []) else {
        //                        assertionFailure("Failed to create pipeline")
        //                        continue itemIterator
        //                    }
        //
        //                    let emptyEntity = EmptyEntity()
        //                    emptyEntity.components += ExctractedMeshPart2d(part: part, material: item.material, modelUniform: uniform)
        //
        //                    items.append(
        //                        Transparent2DRenderItem(
        //                            entity: emptyEntity,
        //                            batchEntity: emptyEntity,
        //                            drawPassId: Self.mesh2dDrawPassIdentifier,
        //                            renderPipeline: pipeline,
        //                            sortKey: .greatestFiniteMagnitude // by default we render debug entities on top of scene.
        //                        )
        //                    )
        //                }
        //            }
        //        }
    }
}
