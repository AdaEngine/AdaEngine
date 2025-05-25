//
//  Text2DRenderSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/7/23.
//

import AdaECS

// FIXME: Should works with frustum culling

// FIXME: WE SHOULD USE SAME SPRITE RENDERER!!!!!!
public struct Text2DRenderSystem: RenderSystem, Sendable {

    public static let dependencies: [SystemDependency] = [
        .after(VisibilitySystem.self),
        .before(BatchTransparent2DItemsSystem.self)
    ]

    static let quadPosition: [Vector4] = [
        [-0.5, -0.5,  0.0, 1.0],
        [ 0.5, -0.5,  0.0, 1.0],
        [ 0.5,  0.5,  0.0, 1.0],
        [-0.5,  0.5,  0.0, 1.0]
    ]

    static let maxTexturesPerBatch = 16

    static let textComponents = EntityQuery(where: .has(Text2DComponent.self) && .has(Transform.self) && .has(Visibility.self) && .has(TextLayoutComponent.self))

    static let cameras = EntityQuery(where:
            .has(VisibleEntities.self) &&
        .has(RenderItems<Transparent2DRenderItem>.self)
    )

    let textRenderPipeline: RenderPipeline

    public init(world: World) {
        let device = RenderEngine.shared.renderDevice

        let textShader = try! AssetsManager.loadSync(
            ShaderModule.self, 
            at: "Shaders/Vulkan/text.glsl", 
            from: .engineBundle
        )
        var piplineDesc = RenderPipelineDescriptor()
        piplineDesc.vertex = textShader.asset.getShader(for: .vertex)
        piplineDesc.fragment = textShader.asset.getShader(for: .fragment)
        piplineDesc.debugName = "Text Pipeline"

        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "position"),
            .attribute(.vector4, name: "foregroundColor"),
            .attribute(.vector4, name: "outlineColor"),
            .attribute(.vector2, name: "textureCoordinate"),
            .attribute(.int, name: "textureIndex")
        ])

        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<GlyphVertexData>.stride
        piplineDesc.colorAttachments = [ColorAttachmentDescriptor(format: .bgra8, isBlendingEnabled: true)]

        let quadPipeline = device.createRenderPipeline(from: piplineDesc)
        self.textRenderPipeline = quadPipeline
    }

    public func update(context: UpdateContext) {
        context.world.performQuery(Self.cameras).forEach { entity in
            var (visibleEntities, renderItems) = entity.components[VisibleEntities.self, RenderItems<Transparent2DRenderItem>.self]
            self.draw(
                world: context.world,
                visibleEntities: visibleEntities.entities,
                renderItems: &renderItems
            )
                
            entity.components += renderItems
        }
    }

    // swiftlint:disable:next function_body_length
    private func draw(
        world: World,
        visibleEntities: [Entity],
        renderItems: inout RenderItems<Transparent2DRenderItem>
    ) {
        let spriteDraw = SpriteDrawPass.identifier

        let texts = visibleEntities.filter {
            $0.components.has(Text2DComponent.self) && $0.components.has(TextLayoutComponent.self)
        }
            .sorted { lhs, rhs in
                lhs.components[Transform.self]!.position.z < rhs.components[Transform.self]!.position.z
            }

        for entity in texts {
            guard let textLayout = entity.components[TextLayoutComponent.self] else {
                continue
            }

            let currentBatchEntity = EmptyEntity()

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

            currentBatchEntity.components += BatchComponent(textures: textures)

            renderItems.items.append(
                Transparent2DRenderItem(
                    entity: currentBatchEntity,
                    batchEntity: currentBatchEntity,
                    drawPassId: spriteDraw,
                    renderPipeline: self.textRenderPipeline,
                    sortKey: transform.position.z,
                    batchRange: 0..<Int32(glyphs.indeciesCount)
                )
            )

            let device = RenderEngine.shared.renderDevice
            let vertexBuffer = device.createVertexBuffer(
                length: spriteVerticies.count * MemoryLayout<GlyphVertexData>.stride,
                binding: 0
            )
            vertexBuffer.label = "Text2DRenderSystem_VertexBuffer"

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

            let quadIndexBuffer = device.createIndexBuffer(
                format: .uInt32,
                bytes: &quadIndices,
                length: indicies
            )
            quadIndexBuffer.label = "Text2DRenderSystem_IndexBuffer"

            currentBatchEntity.components += SpriteDataComponent(
                vertexBuffer: vertexBuffer,
                indexBuffer: quadIndexBuffer
            )
        }
    }
}

@System(dependencies: [
    .after(VisibilitySystem.self),
    .after(Text2DLayoutSystem.self)
])
struct ExctractTextSystem {

    @EntityQuery(
        where: .has(Text2DComponent.self) && .has(Transform.self) &&
            .has(Visibility.self) && .has(TextLayoutComponent.self)
    )
    private var textComponents

    init(world: World) { }

    func update(context: UpdateContext) {
        self.textComponents.forEach { entity in
            if entity.components[Visibility.self] == .hidden {
                return
            }

            let exctractedEntity = EmptyEntity()
            exctractedEntity.components += entity.components[Transform.self]!
            exctractedEntity.components += entity.components[Text2DComponent.self]!

            context.scheduler.addTask {
                await Application.shared.renderWorld.addEntity(exctractedEntity)
            }
        }
    }
}
