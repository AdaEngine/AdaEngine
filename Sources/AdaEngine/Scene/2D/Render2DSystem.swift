//
//  Render2DSystem.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

struct SpriteRenderSystem: System {
    
    static var dependencies: [SystemDependency] = [.before(Physics2DSystem.self)]
    
    static let cameras = EntityQuery(where:
            .has(Camera.self) &&
            .has(VisibleEntities.self) &&
            .has(Transform.self) &&
            .has(RenderItems<Transparent2DRenderItem>.self)
    )
    
    static let quadPosition = [
        [-0.5, -0.5,  0.0, 1.0],
        [ 0.5, -0.5,  0.0, 1.0],
        [ 0.5,  0.5,  0.0, 1.0],
        [-0.5,  0.5,  0.0, 1.0]
    ]
    
    let quadRenderPipeline: RenderPipeline
    
    private static var maxQuads = 20_000
    private static var maxVerticies = maxQuads * 4
    private static var maxIndecies = maxQuads * 6
    
    init(scene: Scene) {
        let device = RenderEngine.shared
        
        var quadIndices = [UInt32].init(repeating: 0, count: Self.maxIndecies)
        
        var offset: UInt32 = 0
        for index in stride(from: 0, to: Self.maxIndecies, by: 6) {
            quadIndices[index + 0] = offset + 0
            quadIndices[index + 1] = offset + 1
            quadIndices[index + 2] = offset + 2
            
            quadIndices[index + 3] = offset + 2
            quadIndices[index + 4] = offset + 3
            quadIndices[index + 5] = offset + 0
            
            offset += 4
        }
        
        let quadIndexBuffer = device.makeIndexBuffer(
            index: 0,
            format: .uInt32,
            bytes: &quadIndices,
            length: Self.maxIndecies
        )
        
        var samplerDesc = SamplerDescriptor()
        samplerDesc.magFilter = .nearest
        samplerDesc.mipFilter = .nearest
        let sampler = device.makeSampler(from: samplerDesc)
        
        let quadShaderDesc = ShaderDescriptor(
            shaderName: "quad",
            vertexFunction: "quad_vertex",
            fragmentFunction: "quad_fragment"
        )
        
        let shader = device.makeShader(from: quadShaderDesc)
        var piplineDesc = RenderPipelineDescriptor(shader: shader)
        piplineDesc.debugName = "Quad Pipline"
        piplineDesc.sampler = sampler
        
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "position"),
            .attribute(.vector4, name: "color"),
            .attribute(.vector2, name: "textureCoordinate"),
            .attribute(.int, name: "textureIndex"),
        ])
        
        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<QuadVertexData>.stride
        
        var attachment = ColorAttachmentDescriptor(format: .bgra8)
        attachment.isBlendingEnabled = true
        
        piplineDesc.colorAttachments = [attachment]
        
        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<QuadVertexData>.stride
        
        let quadPipeline = device.makeRenderPipeline(from: piplineDesc)
        
        let quadVertexBuffer = device.makeVertexBuffer(
            length: MemoryLayout<QuadVertexData>.stride * Self.maxVerticies,
            binding: 0
        )
        
        self.quadRenderPipeline = quadPipeline
    }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.cameras).forEach { entity in
            var (camera, cameraTransform, visibleEntities, renderItems) = entity.components[Camera.self, Transform.self, VisibleEntities.self, RenderItems<Transparent2DRenderItem>.self]
            
            if !camera.isActive {
                return
            }
            
            if case .window(let id) = camera.renderTarget, id == .empty {
                return
            }
            
            self.draw(
                visibleEntities: visibleEntities.entities,
                renderItems: &renderItems
            )
            
            entity.components += renderItems
        }
    }
    
    private func draw(visibleEntities: [Entity], renderItems: inout RenderItems<Transparent2DRenderItem>) {
        let spriteDraw = SpriteDrawPass.identifier
        let spriteEntity = EmptyEntity(name: "sprite_batch")
        
        for entity in visibleEntities {
            
            let transform = entity.components[Transform.self]!
            
            if let _ = entity.components[SpriteComponent.self] {
                renderItems.items.append(
                    Transparent2DRenderItem(
                        entity: spriteEntity,
                        drawPassId: spriteDraw,
                        renderPipeline: self.quadRenderPipeline,
                        sortKey: transform.position.z
                    )
                )
            }
            
            if let _ = entity.components[BoundingComponent.self] {
                renderItems.items.append(
                    Transparent2DRenderItem(
                        entity: spriteEntity,
                        drawPassId: spriteDraw,
                        renderPipeline: self.quadRenderPipeline,
                        sortKey: Float.greatestFiniteMagnitude
                    )
                )
            }
        }
//        entities.forEach { entity in
//            guard let matrix = entity.components[Transform.self]?.matrix else {
//                assert(true, "Render 2D System don't have required Transform component")
//                
//                return
//            }
//            
//            if let circle = entity.components[Circle2DComponent.self] {
//                drawContext.drawCircle(
//                    transform: matrix,
//                    thickness: circle.thickness,
//                    fade: circle.fade,
//                    color: circle.color
//                )
//            }
//            
//            if let sprite = entity.components[SpriteComponent.self] {
//                drawContext.drawQuad(
//                    transform: matrix,
//                    texture: sprite.texture,
//                    color: sprite.tintColor
//                )
//            }
//            
//            if context.scene.debugOptions.contains(.showBoundingBoxes) {
//                if let bounding = entity.components[BoundingComponent.self] {
//                    switch bounding.bounds {
//                    case .aabb(let aabb):
//                        let size: Vector2 = [aabb.halfExtents.x * 2, aabb.halfExtents.y * 2]
//                        
//                        drawContext.drawQuad(
//                            position: aabb.center,
//                            size: size,
//                            color: context.scene.debugPhysicsColor.opacity(0.5)
//                        )
//                    }
//                }
//            }
//        }
    }
}

struct QuadVertexData {
    let position: Vector4
    let color: Color
    let textureCoordinate: Vector2
    let textureIndex: Int
}

struct SpriteDataComponent: Component {
    let vertexBuffer: VertexBuffer
    let verticies: [QuadVertexData]
}

//struct BatchTransparent2DItemsSystem: System {
//
//    static let query = EntityQuery(where: .has(RenderItems<Transparent2DRenderItem>.self))
//
//    init(scene: Scene) { }
//
//    func update(context: UpdateContext) {
//        context.scene.performQuery(Self.query).forEach { entity in
//            guard var renderItems = entity.components[RenderItems<Transparent2DRenderItem>.self] else {
//                return
//            }
//        }
//    }
//}

struct SpriteDrawPass: DrawPass {
    func render(in context: Context) throws {
        let viewMatrix = context.scene.worldTransformMatrix(for: context.view)
        
    }
}
