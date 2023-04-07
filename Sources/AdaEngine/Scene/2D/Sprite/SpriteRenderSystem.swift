//
//  Render2DSystem.swift
//  
//
//  Created by v.prusakov on 5/10/22.
//

// FIXME: Skipped items when batched a lot of sprites entities

public struct SpriteRenderSystem: System {
    
    public static var dependencies: [SystemDependency] = [
        .before(BatchTransparent2DItemsSystem.self)
    ]
    
    static let cameras = EntityQuery(where: .has(Camera.self) && .has(RenderItems<Transparent2DRenderItem>.self))
    
    static let extractedSprites = EntityQuery(where: .has(ExtractedSprites.self))
    
    struct SpriteVertexData {
        let position: Vector4
        let color: Color
        let textureCoordinate: Vector2
        let textureIndex: Int
    }
    
    static let quadPosition: [Vector4] = [
        [-0.5, -0.5,  0.0, 1.0],
        [ 0.5, -0.5,  0.0, 1.0],
        [ 0.5,  0.5,  0.0, 1.0],
        [-0.5,  0.5,  0.0, 1.0]
    ]
    
    static let maxTexturesPerBatch = 16
    
    let quadRenderPipeline: RenderPipeline
    
    public init(scene: Scene) {
        let device = RenderEngine.shared
        
        let quadShader = try! ResourceManager.load("Shaders/Vulkan/quad.glsl", from: .engineBundle) as ShaderModule
        
        var piplineDesc = RenderPipelineDescriptor()
        piplineDesc.vertex = quadShader.getShader(for: .vertex)
        piplineDesc.fragment = quadShader.getShader(for: .fragment)
        piplineDesc.debugName = "Sprite Pipeline"
        
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "a_Position"),
            .attribute(.vector4, name: "a_Color"),
            .attribute(.vector2, name: "a_TexCoordinate"),
            .attribute(.int, name: "a_TexIndex")
        ])
        
        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<SpriteVertexData>.stride
        
        piplineDesc.colorAttachments = [ColorAttachmentDescriptor(format: .bgra8, isBlendingEnabled: true)]
        
        let quadPipeline = device.makeRenderPipeline(from: piplineDesc)
        
        self.quadRenderPipeline = quadPipeline
    }
    
    public func update(context: UpdateContext) {
        let extractedSprites = context.scene.performQuery(Self.extractedSprites)
        
        context.scene.performQuery(Self.cameras).forEach { entity in
            let visibleEntities = entity.components[VisibleEntities.self]!
            var renderItems = entity.components[RenderItems<Transparent2DRenderItem>.self]!
            
            for entity in extractedSprites {
                let extractedSprites = entity.components[ExtractedSprites.self]!
                
                self.draw(
                    extractedSprites: extractedSprites.sprites,
                    visibleEntities: visibleEntities,
                    renderItems: &renderItems
                )
            }
          
            entity.components += renderItems
        }
    }
    
    // MARK: - Private
    
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func draw(
        extractedSprites: [ExtractedSprite],
        visibleEntities: VisibleEntities,
        renderItems: inout RenderItems<Transparent2DRenderItem>
    ) {
        let spriteDraw = SpriteDrawPass.identifier
        
        let spriteData = EmptyEntity(name: "sprite_data")
        
        let sprites = extractedSprites
            .sorted { lhs, rhs in
                lhs.transform.position.z < rhs.transform.position.z
            }
        
        var spriteVerticies = [SpriteVertexData]()
        spriteVerticies.reserveCapacity(MemoryLayout<SpriteVertexData>.stride * sprites.count)
        
        var indeciesCount: Int32 = 0
        
        var textureSlotIndex = 0
        
        var currentBatchEntity = EmptyEntity()
        var currentBatch = BatchComponent(textures: [Texture2D].init(repeating: .whiteTexture, count: Self.maxTexturesPerBatch))
        
        for sprite in sprites {
            guard visibleEntities.entityIds.contains(sprite.entityId) else {
                continue
            }
            
            let worldTransform = sprite.worldTransform
            
            if textureSlotIndex >= Self.maxTexturesPerBatch {
                currentBatchEntity.components += currentBatch
                textureSlotIndex = 0
                currentBatchEntity = EmptyEntity()
                currentBatch = BatchComponent(textures: [Texture2D].init(repeating: .whiteTexture, count: Self.maxTexturesPerBatch))
            }
            // Select a texture index for draw
            let textureIndex: Int
            
            if let texture = sprite.texture {
                if let index = currentBatch.textures.firstIndex(where: { $0 === texture }) {
                    textureIndex = index
                } else {
                    currentBatch.textures[textureSlotIndex] = texture
                    textureIndex = textureSlotIndex
                    textureSlotIndex += 1
                }
            } else {
                // for white texture
                textureIndex = 0
            }
            
            let texture = currentBatch.textures[textureIndex]
            
            for index in 0 ..< Self.quadPosition.count {
                let data = SpriteVertexData(
                    position: worldTransform * Self.quadPosition[index],
                    color: sprite.tintColor,
                    textureCoordinate: texture.textureCoordinates[index],
                    textureIndex: textureIndex
                )
                spriteVerticies.append(data)
            }
            
            let itemStart = indeciesCount
            indeciesCount += 6
            let itemEnd = indeciesCount
            
            renderItems.items.append(
                Transparent2DRenderItem(
                    entity: spriteData,
                    batchEntity: currentBatchEntity,
                    drawPassId: spriteDraw,
                    renderPipeline: self.quadRenderPipeline,
                    sortKey: sprite.transform.position.z,
                    batchRange: itemStart..<itemEnd
                )
            )
        }
        
        currentBatchEntity.components += currentBatch
        
        if spriteVerticies.isEmpty {
            return
        }
        
        let device = RenderEngine.shared
        let vertexBuffer = device.makeVertexBuffer(
            length: spriteVerticies.count * MemoryLayout<SpriteVertexData>.stride,
            binding: 0
        )
        vertexBuffer.label = "SpriteRenderSystem_VertexBuffer"
        
        let indicies = Int(indeciesCount * 4)
        
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
        
        vertexBuffer.setData(&spriteVerticies, byteCount: spriteVerticies.count * MemoryLayout<SpriteVertexData>.stride)
        
        let quadIndexBuffer = device.makeIndexBuffer(
            index: 0,
            format: .uInt32,
            bytes: &quadIndices,
            length: indicies
        )
        quadIndexBuffer.label = "SpriteRenderSystem_IndexBuffer"
        
        spriteData.components += SpriteDataComponent(
            vertexBuffer: vertexBuffer,
            indexBuffer: quadIndexBuffer
        )
    }
}

struct SpriteDataComponent: Component {
    let vertexBuffer: VertexBuffer
    let indexBuffer: IndexBuffer
}

public struct BatchComponent: Component {
    public var textures: [Texture2D]
}

// MARK: Extraction to Render World

public struct ExtractedSprites: Component {
    public var sprites: [ExtractedSprite]
    
    public init(sprites: [ExtractedSprite]) {
        self.sprites = sprites
    }
}

public struct ExtractedSprite: Component {
    public var entityId: Entity.ID
    public var texture: Texture2D?
    public var tintColor: Color
    public var transform: Transform
    public var worldTransform: Transform3D
}

public struct ExtractSpriteSystem: System {
    
    public static var dependencies: [SystemDependency] = [.after(VisibilitySystem.self)]
    
    static let sprites = EntityQuery(where: .has(SpriteComponent.self) && .has(Transform.self) && .has(Visibility.self))
    
    public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
        
        let extractedEntity = EmptyEntity()
        var extractedSprites = ExtractedSprites(sprites: [])
        
        context.scene.performQuery(Self.sprites).forEach { entity in
            let (sprite, transform, visible) = entity.components[SpriteComponent.self, Transform.self, Visibility.self]
            
            if !visible.isVisible {
                return
            }
            
            let worldTransform = context.scene.worldTransformMatrix(for: entity)
            
            extractedSprites.sprites.append(
                ExtractedSprite(
                    entityId: entity.id,
                    texture: sprite.texture,
                    tintColor: sprite.tintColor,
                    transform: transform,
                    worldTransform: worldTransform
                )
            )
        }
        
        extractedEntity.components += extractedSprites
        context.renderWorld.addEntity(extractedEntity)
    }
}
