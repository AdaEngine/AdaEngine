//
//  DebugPhysics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/26/23.
//

struct ExctractedPhysics2DDebug: Component {
    let entity: Entity
    let mesh: Mesh
    let material: Material
    let transform: Transform3D
}

struct DebugPhysicsExctract2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(Physics2DSystem.self)]
    
    static let entities = EntityQuery(
        where: (.has(PhysicsBody2DComponent.self) || .has(Collision2DComponent.self) || .has(PhysicsJoint2DComponent.self)) && .has(Visibility.self)
    )
    
    static let cameras = EntityQuery(where:
            .has(Camera.self) &&
        .has(VisibleEntities.self) &&
        .has(RenderItems<Transparent2DRenderItem>.self)
    )
    
    private let material = CustomMaterial(ColorCanvasMaterial(color: .red))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        guard context.scene.debugOptions.contains(.showPhysicsShapes) else {
            return
        }
        
        self.material.color = context.scene.debugPhysicsColor
        
        context.scene.performQuery(Self.entities).forEach { entity in
            
            if entity.components[Visibility.self]!.isVisible == false {
                return
            }
            
            guard let body = self.getRuntimeBody(from: entity), let mesh = body.debugMesh else {
                return
            }
            
            let emptyEntity = EmptyEntity()
            
            emptyEntity.components += ExctractedPhysics2DDebug(
                entity: entity,
                mesh: mesh,
                material: material,
                transform: Transform3D(translation: Vector3(body.getPosition(), 0), rotation: .identity, scale: Vector3(1))
            )
            
            context.renderWorld.addEntity(emptyEntity)
        }
    }
    
    private func getRuntimeBody(from entity: Entity) -> Body2D? {
        return entity.components[PhysicsBody2DComponent.self]?.runtimeBody
        ?? entity.components[Collision2DComponent.self]?.runtimeBody
    }
}

struct Physics2DDebugDrawSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(SpriteRenderSystem.self), .before(BatchTransparent2DItemsSystem.self)]
    
    static let cameras = EntityQuery(where: .has(Camera.self) && .has(RenderItems<Transparent2DRenderItem>.self))
    static let entities = EntityQuery(where: .has(ExctractedPhysics2DDebug.self))
    
    static let drawPassIdentifier = Mesh2DDrawPass.identifier
    
    init(scene: Scene) {}
    
    func update(context: UpdateContext) {
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
            guard let item = entity.components[ExctractedPhysics2DDebug.self] else {
                continue
            }
            
            if !visibleEntities.entityIds.contains(item.entity.id) {
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
                            drawPassId: Self.drawPassIdentifier,
                            renderPipeline: pipeline,
                            sortKey: .greatestFiniteMagnitude
                        )
                    )
                }
            }
        }
    }
}
