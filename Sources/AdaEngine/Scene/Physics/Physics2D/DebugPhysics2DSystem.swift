//
//  DebugPhysics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/26/23.
//

@Component
struct ExctractedPhysicsMesh2DDebug {
    let entityId: Entity.ID
    let mesh: Mesh
    let material: Material
    let transform: Transform3D
}

/// System for exctracting physics bodies for debug rendering.
public struct DebugPhysicsExctract2DSystem: System {
    
    public static var dependencies: [SystemDependency] = [.after(Physics2DSystem.self)]
    
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
    
    public func update(context: UpdateContext) async {
        guard context.scene.debugOptions.contains(.showPhysicsShapes) else {
            return
        }
        
        self.colorMaterial.color = context.scene.debugPhysicsColor
        self.circleMaterial.color = context.scene.debugPhysicsColor
        
        for entity in context.scene.performQuery(Self.entities) {
            if entity.components[Visibility.self]!.isVisible == false {
                continue
            }
            
            guard let body = self.getRuntimeBody(from: entity) else {
                continue
            }
            
            let fixtureList = body.getFixtureList()
            
            let emptyEntity = EmptyEntity()
            
            let bodyPosition = Vector3(body.getPosition(), 0)
            
            switch fixtureList.type {
            case .circle:
                let radius = fixtureList.shape.getRadius()
                emptyEntity.components += ExctractedPhysicsMesh2DDebug(
                    entityId: entity.id,
                    mesh: self.quadMesh,
                    material: self.circleMaterial,
                    transform: Transform3D(translation: bodyPosition, rotation: .identity, scale: Vector3(radius))
                )
            case .polygon:
                guard let mesh = body.debugMesh else {
                    continue
                }
                
                emptyEntity.components += ExctractedPhysicsMesh2DDebug(
                    entityId: entity.id,
                    mesh: mesh,
                    material: self.colorMaterial,
                    transform: Transform3D(translation: bodyPosition, rotation: .identity, scale: Vector3(1))
                )
            default:
                continue
            }

            await Application.shared.renderWorld.addEntity(emptyEntity)
        }
    }
    
    private func getRuntimeBody(from entity: Entity) -> Body2D? {
        return entity.components[PhysicsBody2DComponent.self]?.runtimeBody
        ?? entity.components[Collision2DComponent.self]?.runtimeBody
    }
}

/// System for rendering debug physics shape on top of the scene.
public struct Physics2DDebugDrawSystem: System {
    
    public static var dependencies: [SystemDependency] = [.after(SpriteRenderSystem.self), .before(BatchTransparent2DItemsSystem.self)]
    
    static let cameras = EntityQuery(where: .has(Camera.self) && .has(RenderItems<Transparent2DRenderItem>.self))
    static let entities = EntityQuery(where: .has(ExctractedPhysicsMesh2DDebug.self))
    
    static let mesh2dDrawPassIdentifier = Mesh2DDrawPass.identifier
    
    public init(scene: Scene) {}
    
    public func update(context: UpdateContext) async {
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
    
    private func draw(
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
