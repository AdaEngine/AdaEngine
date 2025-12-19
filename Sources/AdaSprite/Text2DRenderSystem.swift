//
//  Text2DRenderSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/7/23.
//

import AdaAssets
import AdaECS
import AdaRender
import AdaCorePipelines
import AdaTransform
import AdaText
import Math

@PlainSystem
public struct Text2DRenderSystem {

    static let quadPosition: [Vector4] = [
        [-0.5, -0.5,  0.0, 1.0],
        [ 0.5, -0.5,  0.0, 1.0],
        [ 0.5,  0.5,  0.0, 1.0],
        [-0.5,  0.5,  0.0, 1.0]
    ]

    static let maxTexturesPerBatch = 16

    @Query<TextComponent, TextLayoutComponent, Transform, Visibility>
    private var textComponents

    @FilterQuery<VisibleEntities, With<Camera>>
    private var cameras

    @Res<RenderItems<Transparent2DRenderItem>>
    private var renderItems

    @Res
    private var spriteDraw: SpriteDrawPass

    @Commands
    private var commands

    @ResMut
    private var pipelines: RenderPipelines<TextPipeline>

    @Res
    private var renderDevice: RenderDeviceHandler

    public init(world: World) {}

    public func update(context: UpdateContext) async {
        self.cameras.forEach { visibleEntities in
            self.draw(
                world: context.world,
                visibleEntities: visibleEntities.entities
            )
        }
    }

    // swiftlint:disable:next function_body_length
    private func draw(
        world: World,
        visibleEntities: [Entity]
    ) {
        let texts = visibleEntities.filter {
            $0.components.has(TextComponent.self) && $0.components.has(TextLayoutComponent.self)
        }
            .sorted { lhs, rhs in
                lhs.components[Transform.self]!.position.z < rhs.components[Transform.self]!.position.z
            }

        for entity in texts {
            guard let textLayout = entity.components[TextLayoutComponent.self] else {
                continue
            }

            let currentBatchEntity = commands.spawn()
            let transform = entity.components[Transform.self]!
            let worldTransform = entity.components[GlobalTransform.self]!.matrix
            let glyphs = textLayout.textLayout.getGlyphVertexData(transform: worldTransform)

            var spriteVerticies = glyphs.verticies

            if spriteVerticies.isEmpty {
                continue
            }

            // TODO: Redesign it latter
            var textures: [Texture2D] = [Texture2D].init(repeating: .whiteTexture, count: Self.maxTexturesPerBatch)
            glyphs.textures.compactMap { $0 }.enumerated().forEach { index, texture in
                textures[index] = texture
            }

//            currentBatchEntity.components += TextureBatchComponent(textures: textures)

//            renderItems.items.append(
//                Transparent2DRenderItem(
//                    entity: currentBatchEntity,
//                    batchEntity: currentBatchEntity,
//                    drawPassId: spriteDraw,
//                    renderPipeline: self.textRenderPipeline,
//                    sortKey: transform.position.z,
//                    batchRange: 0..<Int32(glyphs.indeciesCount)
//                )
//            )

//            let vertexBuffer = device.createVertexBuffer(
//                length: spriteVerticies.count * MemoryLayout<GlyphVertexData>.stride,
//                binding: 0
//            )
//            vertexBuffer.label = "Text2DRenderSystem_VertexBuffer"

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

//            vertexBuffer.setData(&spriteVerticies, byteCount: spriteVerticies.count * MemoryLayout<GlyphVertexData>.stride)

//            let quadIndexBuffer = device.createIndexBuffer(
//                format: .uInt32,
//                bytes: &quadIndices,
//                length: indicies
//            )
//            quadIndexBuffer.label = "Text2DRenderSystem_IndexBuffer"
//
//            currentBatchEntity.components += SpriteDataComponent(
//                vertexBuffer: vertexBuffer,
//                indexBuffer: quadIndexBuffer
//            )
        }
    }
}

@PlainSystem(dependencies: [
    .after(TextLayoutSystem.self)
])
struct ExctractTextSystem {

    @Query<TextComponent, TextLayoutComponent, GlobalTransform>
    private var textComponents

    @ResMut
    private var extractedSprites: ExtractedSprites

    init(world: World) { }

    func update(context: UpdateContext) {
        self.textComponents.forEach { textComponent, textLayoutComponent, transform in

        }
    }
}

public struct ExctractedText {

}
