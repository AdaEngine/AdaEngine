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
import AdaUtils
import Math

// MARK: - Text Data Structures

/// A resource that contains the extracted text entities.
public struct ExtractedTexts: Resource {
    /// The extracted texts.
    public var texts: SparseSet<Entity.ID, ExtractedText> = [:]

    public init() {}
}

/// An extracted text entity ready for rendering.
public struct ExtractedText: Sendable {
    /// The entity id of the extracted text.
    public var entityId: Entity.ID
    /// The text layout for rendering.
    public var textLayout: TextLayoutManager
    /// The transform of the text.
    public var transform: Transform
    /// The world transform of the text.
    public var worldTransform: Transform3D
}

/// A batch of text glyphs for a single text entity.
public struct TextBatch: Sendable {
    /// The range of glyph quads in the index buffer for this batch.
    public var range: Range<Int32>
}

/// A resource that contains all text batches for rendering.
public struct TextBatches: Resource {
    /// Map from batch entity ID to text batch data.
    public var batches: [Entity.ID: TextBatch] = [:]

    public init() {}
}

/// Maximum number of font atlas textures per batch (matches shader).
private let maxFontAtlasTextures = 16

/// A resource containing GPU buffers for text rendering.
public struct TextDrawData: Resource, WorldInitable {
    public var vertexBuffer: BufferData<GlyphVertexData>
    public var indexBuffer: BufferData<UInt32>
    /// Font atlas textures used during rendering (max 16).
    public var fontAtlases: [Texture2D]

    public init(from world: World) {
        self.vertexBuffer = BufferData(label: "Text2D_VertexBuffer", elements: [])
        self.indexBuffer = BufferData(label: "Text2D_IndexBuffer", elements: [])
        self.fontAtlases = Array(repeating: .whiteTexture, count: maxFontAtlasTextures)
    }

    mutating func clear() {
        vertexBuffer.elements.removeAll(keepingCapacity: true)
        indexBuffer.elements.removeAll(keepingCapacity: true)
        // Reset font atlases to white texture
        for i in 0..<fontAtlases.count {
            fontAtlases[i] = .whiteTexture
        }
    }
}

// MARK: - Extract Text System

/// Extracts text components to RenderWorld for future rendering.
@System
@inline(__always)
public func ExtractText(
    _ texts: Extract<
        Query<Entity, TextComponent, TextLayoutComponent, GlobalTransform, Transform, Visibility>
    >,
    _ extractedTexts: ResMut<ExtractedTexts>
) {
    extractedTexts.texts.removeAll(keepingCapacity: true)

    texts.wrappedValue.forEach { entity, textComponent, textLayoutComponent, globalTransform, transform, visible in
        if visible == .hidden {
            return
        }
        extractedTexts.texts[entity.id] = ExtractedText(
            entityId: entity.id,
            textLayout: textLayoutComponent.textLayout,
            transform: transform,
            worldTransform: globalTransform.matrix
        )
    }
}

// MARK: - Prepare Texts System

/// Prepares text render items for rendering.
@System
func PrepareTexts(
    _ camera: Query<Camera, VisibleEntities>,
    _ renderItems: ResMut<RenderItems<Transparent2DRenderItem>>,
    _ textRenderPipeline: ResMut<RenderPipelines<TextPipeline>>,
    _ renderDevice: Res<RenderDeviceHandler>,
    _ extractedTexts: Res<ExtractedTexts>,
    _ textDrawPass: Res<TextDrawPass>
) {
    camera.forEach { camera, entities in
        for text in extractedTexts.texts {
            let pipeline = textRenderPipeline.wrappedValue.pipeline(device: renderDevice.renderDevice)
            renderItems.items.append(
                Transparent2DRenderItem(
                    entity: text.entityId,
                    drawPass: textDrawPass.wrappedValue,
                    renderPipeline: pipeline,
                    sortKey: text.transform.position.z,
                    batchRange: 0..<0
                )
            )
        }
    }
}

// MARK: - Text Render System

/// System that prepares text vertex and index buffers for rendering.
@PlainSystem
public struct Text2DRenderSystem {

    @ResMut<SortedRenderItems<Transparent2DRenderItem>>
    private var renderItems

    @Res<ExtractedTexts>
    private var extractedTexts

    @ResMut<TextBatches>
    private var textBatches

    @ResMut<TextDrawData>
    private var textDrawData

    @Res<RenderDeviceHandler>
    private var renderDevice

    public init(world: World) {}

    public func update(context: UpdateContext) {
        textBatches.batches.removeAll(keepingCapacity: true)
        let device = renderDevice.renderDevice

        // Clear previous frame data
        textDrawData.clear()
        
        var instanceCount: Int32 = 0

        // Shared texture slot index for all texts in this frame
        var textureSlotIndex: Int = -1

        for index in renderItems.items.items.indices {
            let itemEntity = renderItems.items.items[index].entity
            guard let text = extractedTexts.texts[itemEntity] else {
                continue
            }

            let worldTransform = text.worldTransform
            let batchStart = instanceCount

            // Get glyph vertex data from text layout
            // This populates textDrawData.fontAtlases with actual font textures
            let glyphData = text.textLayout.getGlyphVertexData(
                transform: worldTransform,
                textures: &textDrawData.fontAtlases,
                textureSlotIndex: &textureSlotIndex,
                ignoreCache: true
            )

            if glyphData.verticies.isEmpty {
                continue
            }

            // Add glyph vertices
            let vertexOffset = UInt32(textDrawData.vertexBuffer.count)
            textDrawData.vertexBuffer.elements.append(contentsOf: glyphData.verticies)

            // Generate indices for all glyphs (6 indices per glyph quad)
            let glyphCount = glyphData.verticies.count / 4
            for glyphIndex in 0..<glyphCount {
                let baseVertex = vertexOffset + UInt32(glyphIndex * 4)

                // Triangle 1: 0, 1, 2
                textDrawData.indexBuffer.append(baseVertex + 0)
                textDrawData.indexBuffer.append(baseVertex + 1)
                textDrawData.indexBuffer.append(baseVertex + 2)

                // Triangle 2: 2, 3, 0
                textDrawData.indexBuffer.append(baseVertex + 2)
                textDrawData.indexBuffer.append(baseVertex + 3)
                textDrawData.indexBuffer.append(baseVertex + 0)

                instanceCount += 1
            }

            // Create batch for this text entity
            textBatches.batches[itemEntity] = TextBatch(
                range: batchStart..<instanceCount
            )
        }

        // Early exit if no text to render
        if textDrawData.vertexBuffer.isEmpty {
            return
        }

        // Write buffers to GPU
        textDrawData.vertexBuffer.write(to: device)
        textDrawData.indexBuffer.write(to: device)
    }
}

// MARK: - Text Draw Pass

/// Draw pass for rendering 2D text.
public struct TextDrawPass: DrawPass {
    public typealias Item = Transparent2DRenderItem

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: Transparent2DRenderItem
    ) throws {
        guard
            let cameraViewUniform = view.components[GlobalViewUniformBufferSet.self],
            let textDrawData = world.getResource(TextDrawData.self),
            let textBatches = world.getResource(TextBatches.self)
        else {
            return
        }

        guard let batch = textBatches.batches[item.entity] else {
            return
        }

        renderEncoder.pushDebugName("TextDrawPass")
        defer {
            renderEncoder.popDebugName()
        }

        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        // Bind all 16 font atlas textures (shader expects array of 16 samplers)
        for (index, texture) in textDrawData.fontAtlases.enumerated() {
            renderEncoder.setFragmentTexture(texture, index: index)
            renderEncoder.setFragmentSamplerState(texture.sampler, index: index)
        }

        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: GlobalBufferIndex.viewUniform)
        renderEncoder.setVertexBuffer(textDrawData.vertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(textDrawData.indexBuffer, indexFormat: .uInt32)
        renderEncoder.setRenderPipelineState(item.renderPipeline)

        let instanceCount = Int(batch.range.upperBound - batch.range.lowerBound)
        let indexBufferOffset = Int(batch.range.lowerBound) * MemoryLayout<UInt32>.stride

        renderEncoder.drawIndexed(
            indexCount: 6 * instanceCount,
            indexBufferOffset: 6 * indexBufferOffset,
            instanceCount: 1
        )
    }
}
