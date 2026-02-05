//
//  UIRenderPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 04.12.2025.
//

import AdaApp
import AdaCorePipelines
import AdaECS
import AdaRender
import AdaText
import AdaUtils
import Logging
import Math

public struct ExtractedUIComponents: Resource {
    public var components: ContiguousArray<UIComponent> = []
}

public struct ExtractedUIContexts: Resource {
    public var contexts: ContiguousArray<UIGraphicsContext> = []
}

public struct UIRenderBuildState: Resource {
    public var needsRebuild: Bool = true
}

@System
public func ExtractUIComponents(
    _ uiComponents: Extract<
        Query<UIComponent>
    >,
    _ pendingViews: Extract<
        Res<UIWindowPendingDrawViews>
    >,
    _ contexts: Extract<
        Res<UIContextPendingDraw>
    >,
    _ redrawRequest: Extract<
        Res<UIRedrawRequest>
    >,
    _ extractedUIComponents: ResMut<ExtractedUIComponents>,
    _ extractedUIContexts: ResMut<ExtractedUIContexts>,
    _ buildState: ResMut<UIRenderBuildState>
) {
    extractedUIComponents.components.removeAll(keepingCapacity: true)
    extractedUIContexts.contexts.removeAll(keepingCapacity: true)

    pendingViews().windows.forEach {
        extractedUIComponents.components.append(UIComponent(view: $0, behaviour: .default))
    }
    uiComponents().forEach {
        extractedUIComponents.components.append($0)
    }
    extractedUIContexts.contexts.append(contentsOf: contexts().contexts)

    buildState.needsRebuild = redrawRequest().needsRedraw
        || !pendingViews().windows.isEmpty
        || !contexts().contexts.isEmpty
}

public struct PendingUIGraphicsContext: Resource {
    public var graphicContexts: ContiguousArray<UIGraphicsContext> = []
}

@System
@MainActor
public func UIRenderPreparing(
    _ cameras: Query<Camera>,
    _ uiComponents: Res<ExtractedUIComponents>,
    _ contexts: ResMut<PendingUIGraphicsContext>,
    _ extractedUIContexts: ResMut<ExtractedUIContexts>,
    _ buildState: Res<UIRenderBuildState>
) {
    guard buildState.needsRebuild else {
        return
    }
    contexts.graphicContexts.removeAll(keepingCapacity: true)
    uiComponents.components.forEach { component in
        let context = UIGraphicsContext()
        component.view.draw(with: context)
        context.commitDraw()
        contexts.graphicContexts.append(context)
    }
    contexts.graphicContexts.append(contentsOf: extractedUIContexts.contexts)
}

// MARK: - UIRenderTesselationSystem

/// System that tessellates UI draw commands into vertex and index data.
@PlainSystem
public struct UIRenderTesselationSystem {

    /// Maximum number of textures per batch.
    private static let maxTexturesPerBatch = 16

    @ResMut<RenderItems<UITransparentRenderItem>>
    private var renderItems

    @ResMut<PendingUIGraphicsContext>
    private var contexts

    @ResMut<UIRenderBuildState>
    private var buildState

    @Res<UIDrawPass>
    private var uiDrawPass

    @Res<RenderDeviceHandler>
    private var renderDevice

    @Res<UIRenderPipelines>
    private var renderPipelines

    public init(world: World) { }

    public func update(context: UpdateContext) {
        guard buildState.needsRebuild else {
            return
        }
        renderItems.items.removeAll()

        let tessellator = UITessellator()
        var currentLineWidth: Float = 1.0
        var textureSlotIndex: Int = 0
        var fontAtlasSlotIndex: Int = 0

        var renderData = UIDrawData()
        renderData.textures = [Texture2D](repeating: .whiteTexture, count: Self.maxTexturesPerBatch)
        renderData.fontAtlases = [Texture2D](repeating: .whiteTexture, count: Self.maxTexturesPerBatch)

        contexts.graphicContexts.forEach { context in
            // Process commands in order (not reversed, as draw order matters)
            for command in context.commandQueue.commands {
                switch command {
                case let .setLineWidth(lineWidth):
                    currentLineWidth = lineWidth

                case let .drawQuad(transform, texture, color):
                    let texIndex = findOrAddTexture(
                        texture,
                        in: &renderData.textures,
                        slotIndex: &textureSlotIndex
                    )

                    let vertexOffset = UInt32(renderData.quadVertexBuffer.count)
                    let vertices = tessellator.tessellateQuad(
                        transform: transform,
                        texture: texture,
                        color: color,
                        textureIndex: texIndex
                    )
                    renderData.quadVertexBuffer.elements.append(contentsOf: vertices)

                    let indexStart = renderData.quadIndexBuffer.count
                    let indices = tessellator.generateQuadIndices(vertexOffset: vertexOffset)
                    renderData.quadIndexBuffer.elements.append(contentsOf: indices)
                    appendBatch(
                        textureIndex: texIndex,
                        indexStart: indexStart,
                        indexCount: indices.count,
                        batches: &renderData.quadBatches
                    )

                case let .drawCircle(transform, thickness, fade, color):
                    let vertexOffset = UInt32(renderData.circleVertexBuffer.count)
                    let vertices = tessellator.tessellateCircle(
                        transform: transform,
                        thickness: thickness,
                        fade: fade,
                        color: color
                    )
                    renderData.circleVertexBuffer.elements.append(contentsOf: vertices)

                    let indices = tessellator.generateCircleIndices(vertexOffset: vertexOffset)
                    renderData.circleIndexBuffer.elements.append(contentsOf: indices)

                case let .drawLine(start, end, lineWidth, color):
                    let vertexOffset = UInt32(renderData.lineVertexBuffer.count)
                    let vertices = tessellator.tessellateLine(
                        start: start,
                        end: end,
                        lineWidth: lineWidth,
                        color: color
                    )
                    renderData.lineVertexBuffer.elements.append(contentsOf: vertices)

                    let indices = tessellator.generateLineIndices(vertexOffset: vertexOffset)
                    renderData.lineIndexBuffer.elements.append(contentsOf: indices)

                case let .drawPath(path):
                    let result = tessellator.tessellatePath(
                        path,
                        lineWidth: currentLineWidth,
                        color: .white,
                        transform: .identity
                    )

                    let vertexOffset = UInt32(renderData.lineVertexBuffer.count)
                    renderData.lineVertexBuffer.elements.append(contentsOf: result.vertices)

                    let indices = result.indices.map { $0 + vertexOffset }
                    renderData.lineIndexBuffer.elements.append(contentsOf: indices)

                case let .drawText(textLayout, transform):
                    // Calculate text centering offset
                    let textSize = textLayout.boundingSize()
                    let textAlignment = textLayout.textAlignment
                    
                    var offsetX: Float = 0
                    var offsetY: Float = 0
                    
                    switch textAlignment {
                    case .center:
                        offsetX = -textSize.width / 2
                        if let firstLine = textLayout.textLines.first, !textLayout.textLines.isEmpty {
                            let topY = firstLine.typographicBounds.rect.origin.y
                            let bottomY = topY - textSize.height
                            offsetY = -(topY + bottomY) / 2
                        }
                    case .leading:
                        offsetX = 0
                        if let firstLine = textLayout.textLines.first, !textLayout.textLines.isEmpty {
                            let topY = firstLine.typographicBounds.rect.origin.y
                            let bottomY = topY - textSize.height
                            offsetY = -(topY + bottomY) / 2
                        }
                    case .trailing:
                        offsetX = -textSize.width
                        if let firstLine = textLayout.textLines.first, !textLayout.textLines.isEmpty {
                            let topY = firstLine.typographicBounds.rect.origin.y
                            let bottomY = topY - textSize.height
                            offsetY = -(topY + bottomY) / 2
                        }
                    }
                    
                    // Tessellate all glyphs from the text layout with centering
                    for line in textLayout.textLines {
                        // Calculate line-specific offset for horizontal alignment
                        var lineOffsetX = offsetX
                        if textAlignment == .center || textAlignment == .trailing {
                            let lineWidth = line.typographicBounds.rect.width
                            if textAlignment == .center {
                                lineOffsetX = offsetX + (textSize.width - lineWidth) / 2
                            } else {
                                lineOffsetX = offsetX + (textSize.width - lineWidth)
                            }
                        }
                        
                        for run in line {
                            for glyph in run {
                                // Apply centering offset during tessellation
                                let glyphOffset = Vector2(x: lineOffsetX, y: -offsetY)
                                
                                tessellateGlyph(
                                    glyph,
                                    transform: transform,
                                    offset: glyphOffset,
                                    tessellator: tessellator,
                                    fontAtlasSlotIndex: &fontAtlasSlotIndex,
                                    renderData: &renderData
                                )
                            }
                        }
                    }

                case let .drawGlyph(glyph, transform):
                    tessellateGlyph(
                        glyph,
                        transform: transform,
                        tessellator: tessellator,
                        fontAtlasSlotIndex: &fontAtlasSlotIndex,
                        renderData: &renderData
                    )

                case .commit:
                    renderData.write(to: renderDevice.renderDevice)

                    self.renderItems.items.append(
                        UITransparentRenderItem(
                            sortKey: 0,
                            entity: .zero,
                            drawPass: uiDrawPass,
                            primitiveType: .quad,
                            renderPipeline: renderPipelines,
                            drawData: renderData
                        )
                    )

                    renderData = UIDrawData()
                    renderData.textures = [Texture2D](repeating: .whiteTexture, count: Self.maxTexturesPerBatch)
                    renderData.fontAtlases = [Texture2D](repeating: .whiteTexture, count: Self.maxTexturesPerBatch)
                    textureSlotIndex = 0
                    fontAtlasSlotIndex = 0
                    break
                }
            }
        }

        buildState.needsRebuild = false
    }

    // MARK: - Private Helpers

    private func findOrAddTexture(
        _ texture: Texture2D?,
        in textures: inout [Texture2D],
        slotIndex: inout Int
    ) -> Int {
        guard let texture = texture else {
            // Use white texture at index 0
            return 0
        }

        // Check if texture already exists
        if let existingIndex = textures.firstIndex(where: { $0 === texture }) {
            return existingIndex
        }

        // Add new texture if we have room
        if slotIndex < Self.maxTexturesPerBatch - 1 {
            slotIndex += 1
            textures[slotIndex] = texture
            return slotIndex
        }

        // Fallback to white texture if batch is full
        return 0
    }

    private func tessellateGlyph(
        _ glyph: Glyph,
        transform: Transform3D,
        offset: Vector2 = .zero,
        tessellator: UITessellator,
        fontAtlasSlotIndex: inout Int,
        renderData: inout UIDrawData
    ) {
        let texIndex = findOrAddTexture(
            glyph.textureAtlas,
            in: &renderData.fontAtlases,
            slotIndex: &fontAtlasSlotIndex
        )

        let vertexOffset = UInt32(renderData.glyphVertexBuffer.count)
        let vertices = tessellator.tessellateGlyph(
            glyph,
            transform: transform,
            textureIndex: texIndex,
            offset: offset
        )
        renderData.glyphVertexBuffer.elements.append(contentsOf: vertices)
        let indexStart = renderData.glyphIndexBuffer.count
        let indices = tessellator.generateGlyphIndices(vertexOffset: vertexOffset)
        renderData.glyphIndexBuffer.elements.append(contentsOf: indices)
        appendBatch(
            textureIndex: texIndex,
            indexStart: indexStart,
            indexCount: indices.count,
            batches: &renderData.glyphBatches
        )
    }

    private func appendBatch(
        textureIndex: Int,
        indexStart: Int,
        indexCount: Int,
        batches: inout [UIDrawData.IndexBatch]
    ) {
        if var lastBatch = batches.last, lastBatch.textureIndex == textureIndex {
            let expectedStart = lastBatch.indexOffset + lastBatch.indexCount
            if expectedStart == indexStart {
                lastBatch.indexCount += indexCount
                batches[batches.count - 1] = lastBatch
                return
            }
        }

        batches.append(
            UIDrawData.IndexBatch(
                textureIndex: textureIndex,
                indexOffset: indexStart,
                indexCount: indexCount
            )
        )
    }
}

public struct UIRenderPipelines: Resource, WorldInitable {
    public var textPipeline: RenderPipeline
    public var quadPipeline: RenderPipeline
    public var linePipeline: RenderPipeline
    public var circlePipeline: RenderPipeline

    public init(from world: World) {
        let device = world.getResource(RenderDeviceHandler.self).unwrap().renderDevice
        self.textPipeline = world.getRefResource(RenderPipelines<TextPipeline>.self)
            .wrappedValue
            .pipeline(device: device)

        self.quadPipeline = world.getRefResource(RenderPipelines<QuadPipeline>.self)
            .wrappedValue
            .pipeline(device: device)

        self.linePipeline = world.getRefResource(RenderPipelines<LinePipeline>.self)
            .wrappedValue
            .pipeline(device: device)

        self.circlePipeline = world.getRefResource(RenderPipelines<CirclePipeline>.self)
            .wrappedValue
            .pipeline(device: device)
    }
}

// MARK: - UIRenderItem

/// Render item for UI primitives.
public struct UITransparentRenderItem: RenderItem {
    public var sortKey: Float
    public var entity: Entity.ID
    public var drawPass: any DrawPass
    public var batchRange: Range<Int32>? = nil
    public var renderPipeline: UIRenderPipelines
    public var drawData: UIDrawData

    /// Type of UI primitive being rendered.
    public enum PrimitiveType: Sendable {
        case quad
        case circle
        case line
        case glyph
    }

    public var primitiveType: PrimitiveType

    public init(
        sortKey: Float,
        entity: Entity.ID,
        drawPass: any DrawPass,
        primitiveType: PrimitiveType,
        batchRange: Range<Int32>? = nil,
        renderPipeline: UIRenderPipelines,
        drawData: UIDrawData
    ) {
        self.sortKey = sortKey
        self.entity = entity
        self.drawPass = drawPass
        self.primitiveType = primitiveType
        self.batchRange = batchRange
        self.renderPipeline = renderPipeline
        self.drawData = drawData
    }
}
