//
//  DebugPhysics2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/26/23.
//

struct DebugPhysics2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(Physics2DSystem.self)]
    
    static let entities = EntityQuery(
        where: .has(PhysicsBody2DComponent.self) || .has(Collision2DComponent.self) || .has(PhysicsJoint2DComponent.self),
        filter: .removed
    )
    
    static let cameras = EntityQuery(where:
            .has(Camera.self) &&
        .has(VisibleEntities.self) &&
        .has(RenderItems<Transparent2DRenderItem>.self)
    )
    
    init(scene: Scene) {
    }
    
    func update(context: UpdateContext) {
        guard context.scene.debugOptions.contains(.showPhysicsShapes) else {
            return
        }
        
        let material = CustomMaterial(Debug2DLineMaterial(color: context.scene.debugPhysicsColor))
        
        context.scene.performQuery(Self.cameras).forEach { entity in
            var (camera, visibleEntities, renderItems) = entity.components[Camera.self, VisibleEntities.self, RenderItems<Transparent2DRenderItem>.self]
            
            if !camera.isActive {
                return
            }
            
            self.draw(
                scene: context.scene,
                visibleEntities: visibleEntities.entities,
                material: material,
                renderItems: &renderItems
            )
            
            entity.components += renderItems
        }
    }
    
    private func draw(scene: Scene, visibleEntities: [Entity], material: Material, renderItems: inout RenderItems<Transparent2DRenderItem>) {
        for entity in visibleEntities {
            guard let body = self.getRuntimeBody(from: entity) else {
                continue
            }
            
            let fixture = body.getFixtureList()
            let shape = fixture.shape
            
            switch fixture.type {
            case .polygon:
                let items = self.drawPolygon(body: body, shape: shape, material: material)
                renderItems.items.append(contentsOf: items)
            case .circle:
                continue
            default:
                continue
            }
        }
    }
    
    // MARK: - Debug draw
    
    // FIXME: Use body transform instead
    private func drawPolygon(
        body: Body2D,
        shape: BoxShape2D,
        material: Material
    ) -> [Transparent2DRenderItem] {
        let position = Vector3(body.getPosition(), 1)
        let vertices = shape.getPolygonVertices().map { Vector3($0, 1) }
        var descriptor = MeshDescriptor(name: "Polygon")
        descriptor.indicies = [0, 1, 2, 2, 3, 0]
        descriptor.positions = MeshBuffer(vertices)
        
        let mesh = Mesh.generate(from: [descriptor])
        
        let uniform = Mesh2DUniform(
            model: Transform3D(translation: position, rotation: .identity, scale: .one),
            modelInverseTranspose: .identity
        )
        
        var items = [Transparent2DRenderItem]()
        
        for model in mesh.models {
            for part in model.parts {
                
                guard let pipeline = material.getOrCreatePipeline(for: part.vertexDescriptor, keys: []) else {
                    assertionFailure("No render pipeline for mesh")
                    continue
                }
                
                var emptyEntity = EmptyEntity()
                emptyEntity.components += ExctractedMeshPart2d(part: part, material: material, modelUniform: uniform)
                
                items.append(
                    Transparent2DRenderItem(
                        entity: emptyEntity,
                        batchEntity: emptyEntity,
                        drawPassId: Mesh2DDrawPass.identifier,
                        renderPipeline: pipeline,
                        sortKey: .greatestFiniteMagnitude
                    )
                )
            }
        }
        
        return items
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
    
    private func getRuntimeBody(from entity: Entity) -> Body2D? {
        return entity.components[PhysicsBody2DComponent.self]?.runtimeBody
        ?? entity.components[Collision2DComponent.self]?.runtimeBody
    }
}

struct Debug2DLineMaterial: CanvasMaterial {
    @Uniform(binding: 0, propertyName: "u_Color")
    var color: Color
    
    init(color: Color) {
        self.color = color
    }
    
    static func fragmentShader() throws -> ShaderSource {
        try ColorCanvasMaterial.fragmentShader()
    }
    
    static func configurePipeline(keys: Set<String>, vertex: Shader, fragment: Shader, vertexDescriptor: VertexDescriptor) throws -> RenderPipelineDescriptor {
        var desc = try ColorCanvasMaterial.configurePipeline(keys: keys, vertex: vertex, fragment: fragment, vertexDescriptor: vertexDescriptor)
        
        desc.primitive = .line
        
        return desc
    }
}
