//
//  DebugPhysics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/26/23.
//

@_implementationOnly import box2d
import Math

@Component
struct ExctractedPhysicsMesh2DDebug {
    let entityId: Entity.ID
    let mesh: Mesh
    let material: Material
    let transform: Transform3D
}

/// System for exctracting physics bodies for debug rendering.
public struct DebugPhysicsExctract2DSystem: System {
    
    public static let dependencies: [SystemDependency] = [.after(Physics2DSystem.self)]

    static let entities = EntityQuery(
        where: (.has(PhysicsBody2DComponent.self) || .has(Collision2DComponent.self) || .has(PhysicsJoint2DComponent.self)) && .has(Visibility.self)
    )
    
    static let cameras = EntityQuery(where:
            .has(Camera.self) &&
        .has(VisibleEntities.self) &&
        .has(RenderItems<Transparent2DRenderItem>.self)
    )
    
    private let colorMaterial: CustomMaterial<ColorCanvasMaterial>
    private let circleMaterial: CustomMaterial<CircleCanvasMaterial>

    /// Contains base quad mesh for rendering.
    private let quadMesh = Mesh.generate(from: Quad())
    
    public init(scene: Scene) { 
        colorMaterial = CustomMaterial(ColorCanvasMaterial(color: .red))
        circleMaterial = CustomMaterial(
            CircleCanvasMaterial(
                thickness: 0.03,
                fade: 0,
                color: .red
            )
        )
    }
    
//    public func update(context: UpdateContext) {
//        guard context.scene.debugOptions.contains(.showPhysicsShapes) else {
//            return
//        }
//        
//        self.colorMaterial.color = context.scene.debugPhysicsColor
//        self.circleMaterial.color = context.scene.debugPhysicsColor
//        
//        for entity in context.scene.performQuery(Self.entities) {
//            if entity.components[Visibility.self]!.isVisible == false {
//                continue
//            }
//            
//            guard let body = self.getRuntimeBody(from: entity) else {
//                continue
//            }
//            
//            let shapes = body.getShapes()
//            let emptyEntity = EmptyEntity()
//            let bodyPosition = Vector3(body.getPosition(), 0)
//            for shape in shapes {
//                switch shape.type {
////                case b2_circleShape:
////                    let radius = shape.getRadius()
////                    emptyEntity.components += ExctractedPhysicsMesh2DDebug(
////                        entityId: entity.id,
////                        mesh: self.quadMesh,
////                        material: self.circleMaterial,
////                        transform: Transform3D(translation: bodyPosition, rotation: .identity, scale: Vector3(radius))
////                    )
//                case b2_polygonShape:
//                    guard let mesh = body.debugMesh else {
//                        continue
//                    }
//
//                    emptyEntity.components += ExctractedPhysicsMesh2DDebug(
//                        entityId: entity.id,
//                        mesh: mesh,
//                        material: self.colorMaterial,
//                        transform: Transform3D(translation: bodyPosition, rotation: .identity, scale: Vector3(1))
//                    )
//                default:
//                    continue
//                }
//            }
//
//            Application.shared.renderWorld.addEntity(emptyEntity)
//        }
//    }

    public func update(context: UpdateContext) {
        guard context.scene.debugOptions.contains(.showPhysicsShapes) else {
            return
        }

        guard let world = context.scene.physicsWorld2D else {
            return
        }

        self.colorMaterial.color = context.scene.debugPhysicsColor
        self.circleMaterial.color = context.scene.debugPhysicsColor

        let drawContext = WorldDebugDrawContext(colorMaterial: self.colorMaterial)

        var debugDraw = b2DefaultDebugDraw()
        debugDraw.DrawSolidPolygon = DebugPhysicsExctract2DSystem_DrawSolidPolygon
        debugDraw.context = Unmanaged.passUnretained(drawContext).toOpaque()
        debugDraw.drawShapes = true
        debugDraw.drawAABBs = true
        world.debugDraw(with: debugDraw)

        for item in drawContext.debugItems {
            let emptyEntity = EmptyEntity()
            emptyEntity.components += item
            Application.shared.renderWorld.addEntity(emptyEntity)
        }
    }

    @MainActor private func getRuntimeBody(from entity: Entity) -> Body2D? {
        return entity.components[PhysicsBody2DComponent.self]?.runtimeBody
        ?? entity.components[Collision2DComponent.self]?.runtimeBody
    }
}

///// Draw a closed polygon provided in CCW order.
//void ( *DrawPolygon )( const b2Vec2* vertices, int vertexCount, b2HexColor color, void* context );
//
///// Draw a solid closed polygon provided in CCW order.
//void ( *DrawSolidPolygon )( b2Transform transform, const b2Vec2* vertices, int vertexCount, float radius, b2HexColor color,
//                            void* context );
//
///// Draw a circle.
//void ( *DrawCircle )( b2Vec2 center, float radius, b2HexColor color, void* context );
//
///// Draw a solid circle.
//void ( *DrawSolidCircle )( b2Transform transform, float radius, b2HexColor color, void* context );
//
///// Draw a solid capsule.
//void ( *DrawSolidCapsule )( b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context );
//
///// Draw a line segment.
//void ( *DrawSegment )( b2Vec2 p1, b2Vec2 p2, b2HexColor color, void* context );
//
///// Draw a transform. Choose your own length scale.
//void ( *DrawTransform )( b2Transform transform, void* context );
//
///// Draw a point.
//void ( *DrawPoint )( b2Vec2 p, float size, b2HexColor color, void* context );
//
///// Draw a string in world space
//void ( *DrawString )( b2Vec2 p, const char* s, b2HexColor color, void* context );

private final class WorldDebugDrawContext {
    let colorMaterial: CustomMaterial<ColorCanvasMaterial>
    let entityId: Entity.ID
    var debugItems: [ExctractedPhysicsMesh2DDebug] = []

    init(colorMaterial: CustomMaterial<ColorCanvasMaterial>) {
        self.entityId = RID().id
        self.colorMaterial = colorMaterial
    }
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
    let debugContext = Unmanaged<WorldDebugDrawContext>.fromOpaque(context!).takeUnretainedValue()
    debugContext.colorMaterial.color = .green
    let vertices = (0..<vertexCount).map { index in
        let vertex = verticies[Int(index)]
        return Vector3(x: vertex.x, y: vertex.y, z: 0)
    }
    var meshDesc = MeshDescriptor(name: "FixtureMesh")
    meshDesc.positions = MeshBuffer(vertices)
    // FIXME: We should support 8 vertices
    meshDesc.indicies = [
        0, 1, 2, 2, 3, 0
    ]
    meshDesc.primitiveTopology = .lineStrip
    let mesh = Mesh.generate(from: [meshDesc])
    let debugItem = ExctractedPhysicsMesh2DDebug(
        entityId: debugContext.entityId,
        mesh: mesh,
        material: debugContext.colorMaterial,
        transform: Transform3D(
            translation: Vector3(transform.p.asVector2, 0), rotation: .identity, scale: Vector3(1)
        )
    )
    debugContext.debugItems.append(debugItem)
}

/// System for rendering debug physics shape on top of the scene.
public struct Physics2DDebugDrawSystem: RenderSystem {
    
    public static let dependencies: [SystemDependency] = [.after(SpriteRenderSystem.self), .before(BatchTransparent2DItemsSystem.self)]
    
    static let cameras = EntityQuery(where: .has(Camera.self) && .has(RenderItems<Transparent2DRenderItem>.self))
    static let entities = EntityQuery(where: .has(ExctractedPhysicsMesh2DDebug.self))
    
    static let mesh2dDrawPassIdentifier = Mesh2DDrawPass.identifier
    
    public init(scene: Scene) {}
    
    public func update(context: UpdateContext) {
        let exctractedValues = context.scene.performQuery(Self.entities)
            
        context.scene.performQuery(Self.cameras).forEach { entity in
            let visibleEntities = entity.components[VisibleEntities.self]!
            var renderItems = entity.components[RenderItems<Transparent2DRenderItem>.self]!
            
            self.draw(
                extractedItems: exctractedValues,
                visibleEntities: visibleEntities,
                items: &renderItems.items
            )
            
            entity.components += renderItems
        }
    }
    
    @MainActor private func draw(
        extractedItems: QueryResult,
        visibleEntities: VisibleEntities,
        items: inout [Transparent2DRenderItem]
    ) {
        
    itemIterator:
        for entity in extractedItems {
            
            // Draw meshes
            guard let item = entity.components[ExctractedPhysicsMesh2DDebug.self] else {
                continue
            }
            
            if !visibleEntities.entityIds.contains(item.entityId) {
                continue
            }
            
            let uniform = Mesh2DUniform(
                model: item.transform,
                modelInverseTranspose: .identity
            )
            
            for model in item.mesh.models {
                for part in model.parts {
                    guard let pipeline = item.material.getOrCreatePipeline(for: part.vertexDescriptor, keys: []) else {
                        assertionFailure("Failed to create pipeline")
                        continue itemIterator
                    }
                    
                    let emptyEntity = EmptyEntity()
                    emptyEntity.components += ExctractedMeshPart2d(part: part, material: item.material, modelUniform: uniform)
                    
                    items.append(
                        Transparent2DRenderItem(
                            entity: emptyEntity,
                            batchEntity: emptyEntity,
                            drawPassId: Self.mesh2dDrawPassIdentifier,
                            renderPipeline: pipeline,
                            sortKey: .greatestFiniteMagnitude // by default we render debug entities on top of scene.
                        )
                    )
                }
            }
        }
    }
}
