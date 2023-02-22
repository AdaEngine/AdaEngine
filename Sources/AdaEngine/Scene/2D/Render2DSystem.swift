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
    
    static let quadPosition: [Vector4] = [
        [-0.5, -0.5,  0.0, 1.0],
        [ 0.5, -0.5,  0.0, 1.0],
        [ 0.5,  0.5,  0.0, 1.0],
        [-0.5,  0.5,  0.0, 1.0]
    ]
    
    let quadRenderPipeline: RenderPipeline
    let gpuWhiteTexture: Texture2D
    
    init(scene: Scene) {
        let device = RenderEngine.shared
        
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
        piplineDesc.debugName = "Sprite Pipeline"
        piplineDesc.sampler = sampler
        
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "position"),
            .attribute(.vector4, name: "color"),
            .attribute(.vector2, name: "textureCoordinate"),
            .attribute(.int, name: "textureIndex")
        ])
        
        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<SpriteVertexData>.stride
        
        piplineDesc.colorAttachments = [ColorAttachmentDescriptor(format: .bgra8, isBlendingEnabled: true)]
        
        let quadPipeline = device.makeRenderPipeline(from: piplineDesc)
        
        self.quadRenderPipeline = quadPipeline
        
        let image = Image(width: 1, height: 1, color: .white)
        self.gpuWhiteTexture = Texture2D(image: image)
    }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.cameras).forEach { entity in
            var (camera, _, visibleEntities, renderItems) = entity.components[Camera.self, Transform.self, VisibleEntities.self, RenderItems<Transparent2DRenderItem>.self]
            
            if !camera.isActive {
                return
            }
            
            if case .window(let id) = camera.renderTarget, id == .empty {
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
        let spriteDraw = SpriteDrawPass.identifier
        let spriteData = EmptyEntity(name: "sprite_data")
        
        let sprites = visibleEntities.filter {
            $0.components.has(SpriteComponent.self)
        }
        .sorted { lhs, rhs in
            lhs.components[Transform.self]!.position.z < rhs.components[Transform.self]!.position.z
        }
        
        var spriteVerticies = [SpriteVertexData]()
        spriteVerticies.reserveCapacity(MemoryLayout<SpriteVertexData>.stride * sprites.count)
        
        var indeciesCount: Int32 = 0
        
        var textureSlotIndex = 1
        
        var currentBatchEntity = EmptyEntity()
        var currentBatch = BatchComponent(textures: [Texture2D].init(repeating: gpuWhiteTexture, count: 32))
        
        for entity in sprites {
            
            let transform = entity.components[Transform.self]!
            let worldTransform = scene.worldTransformMatrix(for: entity)
            
            if textureSlotIndex >= 32 {
                currentBatchEntity.components += currentBatch
                textureSlotIndex = 1
                currentBatchEntity = EmptyEntity()
                currentBatch = BatchComponent(textures: [Texture2D].init(repeating: gpuWhiteTexture, count: 32))
            }
            
            if let sprite = entity.components[SpriteComponent.self] {
                
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
                        sortKey: transform.position.z,
                        batchRange: itemStart..<itemEnd
                    )
                )
            }
            
            if scene.debugOptions.contains(.showBoundingBoxes) {
                if let bounding = entity.components[BoundingComponent.self] {
                    guard case .aabb(let aabb) = bounding.bounds else {
                        continue
                    }
                    
                    let size: Vector2 = [aabb.halfExtents.x * 2, aabb.halfExtents.y * 2]
                    let transform = Transform3D(translation: aabb.center) * Transform3D(scale: Vector3(size, 1))
                    
                    for index in 0 ..< Self.quadPosition.count {
                        let data = SpriteVertexData(
                            position: transform * Self.quadPosition[index],
                            color: scene.debugPhysicsColor,
                            textureCoordinate: gpuWhiteTexture.textureCoordinates[index],
                            textureIndex: 0 // white texture
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
                            sortKey: Float.greatestFiniteMagnitude,
                            batchRange: itemStart..<itemEnd
                        )
                    )
                }
            }
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
        
        let indexArray = device.makeIndexArray(indexBuffer: quadIndexBuffer, indexOffset: 0, indexCount: indicies)
        
        spriteData.components += SpriteDataComponent(
            vertexBuffer: vertexBuffer,
            indexArray: indexArray
        )
    }
}

struct SpriteVertexData {
    let position: Vector4
    let color: Color
    let textureCoordinate: Vector2
    let textureIndex: Int
}

struct SpriteDataComponent: Component {
    let vertexBuffer: VertexBuffer
    let indexArray: RID
}

public struct BatchComponent: Component {
    public var textures: [Texture2D]
}

struct BatchTransparent2DItemsSystem: System {

    static let query = EntityQuery(where: .has(RenderItems<Transparent2DRenderItem>.self))

    init(scene: Scene) { }

    func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            guard let renderItems = entity.components[RenderItems<Transparent2DRenderItem>.self] else {
                return
            }
            
            let items = renderItems.items
            var batchedItems: [Transparent2DRenderItem] = []
            batchedItems.reserveCapacity(items.count)
            
            if var currentItem = items.first {
                
                for nextItemIndex in 1..<items.count {
                    let nextItem = items[nextItemIndex]
                    
                    if tryToAddBatch(to: &currentItem, from: nextItem) == false {
                        batchedItems.append(currentItem)
                        currentItem = nextItem
                    }
                }
                
                batchedItems.append(currentItem)
            }
            
            entity.components[RenderItems<Transparent2DRenderItem>.self] = RenderItems(items: batchedItems)
        }
    }
    
    private func tryToAddBatch(to currentItem: inout Transparent2DRenderItem, from otherItem: Transparent2DRenderItem) -> Bool {
        guard let batch = currentItem.batchRange, let otherBatch = otherItem.batchRange else {
            return false
        }
        
        if otherItem.batchEntity !== currentItem.batchEntity {
            return false
        }
        
        if batch.upperBound == otherBatch.lowerBound {
            currentItem.batchRange = batch.lowerBound ..< otherBatch.upperBound
        } else if batch.lowerBound == otherBatch.upperBound {
            currentItem.batchRange = otherBatch.lowerBound ..< batch.upperBound
        } else {
            return false
        }
        
        return true
    }
}

struct SpriteDrawPass: DrawPass {
    
    struct SpriteViewUniform {
        let viewMatrix: Transform3D
    }
    
    let uniformBufferSet: UniformBufferSet
    
    init() {
        uniformBufferSet = RenderEngine.shared.makeUniformBufferSet()
        uniformBufferSet.initBuffers(for: SpriteViewUniform.self, count: 3, binding: 1, set: 0)
    }
    
    func render(in context: Context, item: Transparent2DRenderItem) throws {
        guard let spriteData = context.entity.components[SpriteDataComponent.self] else {
            return
        }
        
        guard let batchSprite = item.batchEntity.components[BatchComponent.self] else {
            return
        }
        
        guard let cameraViewUniform = context.view.components[ViewUniform.self] else {
            return
        }
        
        guard let count = item.batchRange?.count, count > 0 else {
            return
        }
        
        let uniform = uniformBufferSet.getBuffer(binding: 1, set: 0, frameIndex: context.device.currentFrameIndex)
        uniform.setData(SpriteViewUniform(viewMatrix: cameraViewUniform.viewProjectionMatrix))
        
        batchSprite.textures.enumerated().forEach { (index, texture) in
            context.drawList.bindTexture(texture, at: index)
        }
        context.drawList.appendUniformBuffer(uniform)
        context.drawList.appendVertexBuffer(spriteData.vertexBuffer)
        context.drawList.bindIndexArray(spriteData.indexArray)
        context.drawList.bindRenderPipeline(item.renderPipeline)
        
        context.drawList.drawIndexed(indexCount: count, instancesCount: 1)
    }
}
