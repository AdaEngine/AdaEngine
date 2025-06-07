//
//  Render2DSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/10/22.
//

import AdaECS
import AdaRender
import AdaUtils
import AdaTransform
import Math

// TODO: Rewrite sprite batch if needed. Too much drawcalls, I think

@System
public struct SpriteRenderSystem: Sendable {

    @Query<
        Camera,
        VisibleEntities,
        Ref<RenderItems<Transparent2DRenderItem>>
    >
    private var cameras

    @ResQuery
    private var extractedSprites: ExtractedSprites?

    @ResQuery
    private var spriteDrawPass: SpriteDrawPass!

    @ResQuery
    private var spriteRenderPipeline: SpriteRenderPipeline!

    static let quadPosition: [Vector4] = [
        [-0.5, -0.5,  0.0, 1.0],
        [ 0.5, -0.5,  0.0, 1.0],
        [ 0.5,  0.5,  0.0, 1.0],
        [-0.5,  0.5,  0.0, 1.0]
    ]

    static let maxTexturesPerBatch = 16

    public init(world: World) { }

    public func update(context: inout UpdateContext) {
        print("Sprites count", self.extractedSprites?.sprites.count)
        cameras.forEach { (_, visibleEntities, renderItems) in
            self.draw(
                extractedSprites: self.extractedSprites?.sprites ?? [],
                visibleEntities: visibleEntities,
                renderItems: &renderItems.wrappedValue
            )
        }
    }

    // MARK: - Private

    // swiftlint:disable:next function_body_length
    private func draw(
        extractedSprites: [ExtractedSprite],
        visibleEntities: VisibleEntities,
        renderItems: inout RenderItems<Transparent2DRenderItem>
    ) {
        let spriteData = Entity(name: "sprite_data")

        let sprites = extractedSprites
            .sorted { lhs, rhs in
                lhs.transform.position.z < rhs.transform.position.z
            }

        var spriteVerticies = [SpriteVertexData]()
        spriteVerticies.reserveCapacity(MemoryLayout<SpriteVertexData>.stride * sprites.count)

        var indeciesCount: Int32 = 0

        var textureSlotIndex = 1

        var currentBatchEntity = Entity()
        var currentBatch = TextureBatchComponent(
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
                currentBatchEntity = Entity()
                currentBatch = TextureBatchComponent(
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
                    drawPass: self.spriteDrawPass,
                    renderPipeline: self.spriteRenderPipeline.renderPipeline,
                    sortKey: sprite.transform.position.z,
                    batchRange: itemStart..<itemEnd
                )
            )
        }

        currentBatchEntity.components += currentBatch

        if spriteVerticies.isEmpty {
            return
        }

        let device = RenderEngine.shared.renderDevice
        var vertexBuffer = device.createVertexBuffer(
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

        var quadIndexBuffer = device.createIndexBuffer(
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
/// A component that contains the textures for a batch.
public struct TextureBatchComponent {
    /// The textures for a batch.
    public var textures: [Texture2D]
}

// MARK: Extraction to Render World

/// A resource that contains the extracted sprites.
public struct ExtractedSprites: Resource {
    /// The extracted sprites.
    public var sprites: [ExtractedSprite]

    /// Initialize a new extracted sprites.
    ///
    /// - Parameter sprites: The extracted sprites.
    public init(sprites: [ExtractedSprite]) {
        self.sprites = sprites
    }
}

/// A sprite that contains the extracted sprite.
public struct ExtractedSprite: Sendable {
    /// The entity id of the extracted sprite.
    public var entityId: Entity.ID
    /// The texture of the extracted sprite.
    public var texture: Texture2D?
    /// The flip x of the extracted sprite.
    public var flipX: Bool
    /// The flip y of the extracted sprite.
    public var flipY: Bool
    /// The tint color of the extracted sprite.
    public var tintColor: Color
    /// The transform of the extracted sprite.
    public var transform: Transform
    /// The world transform of the extracted sprite.
    public var worldTransform: Transform3D
}

/// Exctract sprites to RenderWorld for future rendering.
@PlainSystem(dependencies: [
    .before(SpriteRenderSystem.self)
])
public func ExtractSprite(
    _ world: World,
    _ sprites: Extract<Query<Entity, SpriteComponent, GlobalTransform, Transform, Visibility>>
) {
    var extractedSprites = ExtractedSprites(sprites: [])
    sprites().wrappedValue.forEach { entity, sprite, globalTransform, transform, visible in
        if visible == .hidden {
            return
        }

        extractedSprites.sprites.append(
            ExtractedSprite(
                entityId: entity.id,
                texture: sprite.texture?.asset,
                flipX: sprite.flipX,
                flipY: sprite.flipY,
                tintColor: sprite.tintColor,
                transform: transform,
                worldTransform: globalTransform.matrix
            )
        )
    }
    world.insertResource(extractedSprites)
}

@PlainSystem
func UpdateBoundings(
    _ entitiesWithTransform: FilterQuery<
    Entity, Transform,
    Or<With<SpriteComponent>, With<Mesh2DComponent>>
    >
) {
    entitiesWithTransform.forEach { entity, transform in
        var bounds: BoundingComponent.Bounds?
        if entity.components.has(SpriteComponent.self) {
            if !entity.components.isComponentChanged(Transform.self) && entity.components.has(BoundingComponent.self) {
                return
            }
            let transform = entity.components[Transform.self]!
            let position = transform.position
            let scale = transform.scale
            let min = Vector3(position.x - scale.x / 2, position.y - scale.y / 2, 0)
            let max = Vector3(position.x + scale.x / 2, position.y + scale.y / 2, 0)
            bounds = .aabb(AABB(min: min, max: max))
        } else if let mesh2d = entity.components[Mesh2DComponent.self] {
            bounds = .aabb(mesh2d.mesh.bounds)
        }
        if let bounds {
            entity.components += BoundingComponent(bounds: bounds)
        }
    }
}
