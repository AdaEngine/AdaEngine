//
//  Text2DPlugin.swift
//  
//
//  Created by v.prusakov on 3/5/23.
//

public struct Text2DPlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) {
        scene.addSystem(Text2DLayoutSystem.self)
        scene.addSystem(Text2DRenderSystem.self)
    }
}

public struct Text2DLayoutSystem: System {
    
    public static var dependencies: [SystemDependency] = [.before(VisibilitySystem.self)]
    
    static let textComponents = EntityQuery(where: .has(Text2DComponent.self) && .has(Transform.self) && .has(Visibility.self))
    
    public init(scene: Scene) {}
    
    public func update(context: UpdateContext) {
        context.scene.performQuery(Self.textComponents).forEach { entity in
            let (text, visibility) = entity.components[Text2DComponent.self, Visibility.self]
            
            if !visibility.isVisible {
                return
            }
            
            let textLayout = entity.components[TextLayoutComponent.self] ?? TextLayoutComponent(textLayout: TextLayoutManager())
            
            textLayout.textLayout.replaceText(text.text)
            
            entity.components += textLayout
        }
    }
}

// FIXME: WE SHOULD USE SAME SPRITE RENDERER!!!!!!

public struct Text2DRenderSystem: System {
    
    public static var dependencies: [SystemDependency] = [
        .after(Text2DLayoutSystem.self),
        .after(VisibilitySystem.self),
        .before(BatchTransparent2DItemsSystem.self)
    ]
    
    static let cameras = EntityQuery(where:
            .has(Camera.self) &&
        .has(VisibleEntities.self) &&
        .has(RenderItems<Transparent2DRenderItem>.self)
    )
    
    let quadRenderPipeline: RenderPipeline
    let gpuWhiteTexture: Texture2D
    
    public init(scene: Scene) {
        let device = RenderEngine.shared
        
        var samplerDesc = SamplerDescriptor()
        samplerDesc.magFilter = .linear
        samplerDesc.mipFilter = .linear
        samplerDesc.minFilter = .linear
        let sampler = device.makeSampler(from: samplerDesc)
        
        let quadShaderDesc = ShaderDescriptor(
            shaderName: "text",
            vertexFunction: "text_vertex",
            fragmentFunction: "text_fragment"
        )
        
        let shader = device.makeShader(from: quadShaderDesc)
        var piplineDesc = RenderPipelineDescriptor(shader: shader)
        piplineDesc.debugName = "Text Pipeline"
        piplineDesc.sampler = sampler
        
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "position"),
            .attribute(.vector4, name: "foregroundColor"),
            .attribute(.vector4, name: "outlineColor"),
            .attribute(.vector2, name: "textureCoordinate"),
            .attribute(.vector2, name: "textureSize"),
            .attribute(.int, name: "textureIndex")
        ])
        
        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<GlyphVertexData>.stride
        
        piplineDesc.colorAttachments = [ColorAttachmentDescriptor(format: .bgra8, isBlendingEnabled: true)]
        
        let quadPipeline = device.makeRenderPipeline(from: piplineDesc)
        self.quadRenderPipeline = quadPipeline
        
        let image = Image(width: 1, height: 1, color: .white)
        self.gpuWhiteTexture = Texture2D(image: image)
    }
    
    static let quadPosition: [Vector4] = [
        [-0.5, -0.5,  0.0, 1.0],
        [ 0.5, -0.5,  0.0, 1.0],
        [ 0.5,  0.5,  0.0, 1.0],
        [-0.5,  0.5,  0.0, 1.0]
    ]
    
    static let textComponents = EntityQuery(where: .has(Text2DComponent.self) && .has(Transform.self) && .has(Visibility.self) && .has(TextLayoutComponent.self))
    
    public func update(context: UpdateContext) {
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
    
    private func draw(
        scene: Scene,
        visibleEntities: [Entity],
        renderItems: inout RenderItems<Transparent2DRenderItem>
    ) {
        
        let spriteDraw = SpriteDrawPass.identifier
        
        let spriteData = EmptyEntity(name: "sprite_data")
        
        let texts = visibleEntities.filter {
            $0.components.has(Text2DComponent.self) && $0.components.has(TextLayoutComponent.self)
        }
            .sorted { lhs, rhs in
                lhs.components[Transform.self]!.position.z < rhs.components[Transform.self]!.position.z
            }
        
        for entity in texts {
            guard
                let textLayout = entity.components[TextLayoutComponent.self],
                let text = entity.components[Text2DComponent.self]
            else {
                continue
            }
            
            let currentBatchEntity = EmptyEntity()
            
            let transform = entity.components[Transform.self]!
            let worldTransform = scene.worldTransformMatrix(for: entity)
            
            let bounds = text.bounds ?? Rect(origin: .zero, size: Size.init(width: .infinity, height: .infinity))
            
            let glyphs = textLayout.textLayout.getGlyphVertexData(
                in: bounds,
                textAlignment: text.textAlignment,
                transform: worldTransform
            )
            
            var spriteVerticies = glyphs.verticies
            
            currentBatchEntity.components += BatchComponent(textures: glyphs.textures.compactMap { $0 })
            
            renderItems.items.append(
                Transparent2DRenderItem(
                    entity: currentBatchEntity,
                    batchEntity: currentBatchEntity,
                    drawPassId: spriteDraw,
                    renderPipeline: self.quadRenderPipeline,
                    sortKey: transform.position.z,
                    batchRange: 0..<Int32(glyphs.indeciesCount)
                )
            )
            
            let device = RenderEngine.shared
            let vertexBuffer = device.makeVertexBuffer(
                length: spriteVerticies.count * MemoryLayout<GlyphVertexData>.stride,
                binding: 0
            )
            
            let indicies = Int(glyphs.indeciesCount * 4)
            
            var quadIndices = [UInt32].init(repeating: 0, count: indicies)
            
            var offset: UInt32 = 0
            for index in stride(from: 0, to: indicies, by: 6) {
                quadIndices[index + 0] = offset + 0
                quadIndices[index + 1] = offset + 1
                quadIndices[index + 2] = offset + 2
                
                quadIndices[index + 3] = offset + 2
                quadIndices[index + 4] = offset + 3
                quadIndices[index + 5] = offset + 0
                
                offset += 4
            }
            
            vertexBuffer.setData(&spriteVerticies, byteCount: spriteVerticies.count * MemoryLayout<GlyphVertexData>.stride)
            
            let quadIndexBuffer = device.makeIndexBuffer(
                index: 0,
                format: .uInt32,
                bytes: &quadIndices,
                length: indicies
            )
            
            currentBatchEntity.components += SpriteDataComponent(
                vertexBuffer: vertexBuffer,
                indexBuffer: quadIndexBuffer
            )
        }
    }
}

struct TextLayoutComponent: Component {
    let textLayout: TextLayoutManager
}
