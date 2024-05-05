//
//  Render2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/10/22.
//

/// System in RenderWorld for render sprites from exctracted sprites.
public struct SpriteRenderSystem: System {

    public static var dependencies: [SystemDependency] = [
        .before(BatchTransparent2DItemsSystem.self)
    ]

    static let cameras = EntityQuery(where: .has(Camera.self) && .has(RenderItems<Transparent2DRenderItem>.self))

    static let extractedSprites = EntityQuery(where: .has(ExtractedSprites.self))

    static let quadPosition: [Vector4] = [
        [-0.5, -0.5,  0.0, 1.0],
        [ 0.5, -0.5,  0.0, 1.0],
        [ 0.5,  0.5,  0.0, 1.0],
        [-0.5,  0.5,  0.0, 1.0]
    ]

    static let maxTexturesPerBatch = 16

    public init(scene: Scene) { }

    public func update(context: UpdateContext) async {
        let extractedSprites = context.scene.performQuery(Self.extractedSprites)

        await context.scene.performQuery(Self.cameras).concurrent.forEach { entity in
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

    // swiftlint:disable:next function_body_length
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

        var textureSlotIndex = 1

        var currentBatchEntity = EmptyEntity()
        var currentBatch = BatchComponent(
            textures: [Texture2D].init(repeating: .whiteTexture, count: Self.maxTexturesPerBatch)
        )

        for sprite in sprites {
            guard visibleEntities.entityIds.contains(sprite.entityId) else {
                continue
            }

            let worldTransform = sprite.worldTransform

            if textureSlotIndex >= Self.maxTexturesPerBatch {
                currentBatchEntity.components += currentBatch
                textureSlotIndex = 1
                currentBatchEntity = EmptyEntity()
                currentBatch = BatchComponent(
                    textures: [Texture2D].init(repeating: .whiteTexture, count: Self.maxTexturesPerBatch)
                )
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
                    renderPipeline: SpriteRenderPipeline.default.renderPipeline,
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

@Component
struct SpriteDataComponent {
    let vertexBuffer: VertexBuffer
    let indexBuffer: IndexBuffer
}

@Component
public struct BatchComponent {
    public var textures: [Texture2D]
}

// MARK: Extraction to Render World

@Component
public struct ExtractedSprites {
    public var sprites: [ExtractedSprite]

    public init(sprites: [ExtractedSprite]) {
        self.sprites = sprites
    }
}

@Component
public struct ExtractedSprite {
    public var entityId: Entity.ID
    public var texture: Texture2D?
    public var tintColor: Color
    public var transform: Transform
    public var worldTransform: Transform3D
}

/// Exctract sprites to RenderWorld for future rendering.
public struct ExtractSpriteSystem: System {

    public static let dependencies: [SystemDependency] = [.after(VisibilitySystem.self)]

    static let sprites = EntityQuery(where: .has(SpriteComponent.self) && .has(Transform.self) && .has(Visibility.self))

    public init(scene: Scene) { }

    public func update(context: UpdateContext) async {
        let extractedEntity = EmptyEntity()
        var extractedSprites = ExtractedSprites(sprites: [])

        context.scene.performQuery(Self.sprites).forEach { entity in
            let (sprite, transform, visible) = entity.components[SpriteComponent.self, Transform.self, Visibility.self]

            if !visible.isVisible {
                return
            }

            extractedSprites.sprites.append(
                ExtractedSprite(
                    entityId: entity.id,
                    texture: sprite.texture,
                    tintColor: sprite.tintColor,
                    transform: transform,
                    worldTransform: transform.matrix
                )
            )
        }

        extractedEntity.components += extractedSprites

        await Application.shared.renderWorld.addEntity(extractedEntity)
    }
}
