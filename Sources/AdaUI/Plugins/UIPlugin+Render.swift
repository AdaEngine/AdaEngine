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

@System
public func ExtractUIComponents(
    _ uiComponents: Extract<
        Query<UIComponent>
    >,
    _ pendingViews: Extract<
        Res<UIWindowPendingDrawViews>
    >,
    _ extractedUIComponents: ResMut<ExtractedUIComponents>
) {
    extractedUIComponents.components.removeAll(keepingCapacity: true)

    pendingViews().windows.forEach {
        extractedUIComponents.components.append(UIComponent(view: $0, behaviour: .default))
    }
    uiComponents().forEach {
        extractedUIComponents.components.append($0)
    }
}

public struct PendingUIGraphicsContext: Resource {
    public var graphicContexts: ContiguousArray<UIGraphicsContext> = []
}

@System
@MainActor
public func UIRenderPreparing(
    _ cameras: Query<Camera>,
    _ uiComponents: Res<ExtractedUIComponents>,
    _ contexts: ResMut<PendingUIGraphicsContext>
) {
    contexts.graphicContexts.removeAll(keepingCapacity: true)
    uiComponents.components.forEach { component in
        let context = UIGraphicsContext()
        component.view.draw(with: context)

        contexts.graphicContexts.append(context)
    }
}

// MARK: - UIRenderTesselationSystem

/// System that tessellates UI draw commands into vertex and index data.
@PlainSystem
public struct UIRenderTesselationSystem {

    /// Maximum number of textures per batch.
    private static let maxTexturesPerBatch = 16

    @ResMut<PendingUIGraphicsContext>
    private var contexts

    @ResMut<UIRenderData>
    private var renderData

    public init(world: World) { }

    public func update(context: UpdateContext) {
        // Clear previous frame data
        renderData.clear()

        // Initialize texture slots
        renderData.textures = [Texture2D](repeating: .whiteTexture, count: Self.maxTexturesPerBatch)
        renderData.fontAtlases = [Texture2D](repeating: .whiteTexture, count: Self.maxTexturesPerBatch)

        let tessellator = UITessellator()
        var currentLineWidth: Float = 1.0
        var textureSlotIndex: Int = 0
        var fontAtlasSlotIndex: Int = 0

        for graphicsContext in contexts.graphicContexts {
            // Process commands in order (not reversed, as draw order matters)
            for command in graphicsContext.commandQueue.commands {
                switch command {
                case let .setLineWidth(lineWidth):
                    currentLineWidth = lineWidth

                case let .drawQuad(transform, texture, color):
                    let texIndex = findOrAddTexture(
                        texture,
                        in: &renderData.textures,
                        slotIndex: &textureSlotIndex
                    )

                    let vertexOffset = UInt32(renderData.quadVertices.count)
                    let vertices = tessellator.tessellateQuad(
                        transform: transform,
                        texture: texture,
                        color: color,
                        textureIndex: texIndex
                    )
                    renderData.quadVertices.append(contentsOf: vertices)

                    let indices = tessellator.generateQuadIndices(vertexOffset: vertexOffset)
                    renderData.quadIndices.append(contentsOf: indices)

                case let .drawCircle(transform, thickness, fade, color):
                    let vertexOffset = UInt32(renderData.circleVertices.count)
                    let vertices = tessellator.tessellateCircle(
                        transform: transform,
                        thickness: thickness,
                        fade: fade,
                        color: color
                    )
                    renderData.circleVertices.append(contentsOf: vertices)

                    let indices = tessellator.generateCircleIndices(vertexOffset: vertexOffset)
                    renderData.circleIndices.append(contentsOf: indices)

                case let .drawLine(start, end, lineWidth, color):
                    let vertexOffset = UInt32(renderData.lineVertices.count)
                    let vertices = tessellator.tessellateLine(
                        start: start,
                        end: end,
                        lineWidth: lineWidth,
                        color: color
                    )
                    renderData.lineVertices.append(contentsOf: vertices)

                    let indices = tessellator.generateLineIndices(vertexOffset: vertexOffset)
                    renderData.lineIndices.append(contentsOf: indices)

                case let .drawPath(path):
                    let result = tessellator.tessellatePath(
                        path,
                        lineWidth: currentLineWidth,
                        color: .white,
                        transform: .identity
                    )

                    let vertexOffset = UInt32(renderData.lineVertices.count)
                    renderData.lineVertices.append(contentsOf: result.vertices)

                    let indices = result.indices.map { $0 + vertexOffset }
                    renderData.lineIndices.append(contentsOf: indices)

                case let .drawText(textLayout, transform):
                    // Tessellate all glyphs from the text layout
                    for line in textLayout.textLines {
                        for run in line {
                            for glyph in run {
                                tessellateGlyph(
                                    glyph,
                                    transform: transform,
                                    tessellator: tessellator,
                                    fontAtlasSlotIndex: &fontAtlasSlotIndex
                                )
                            }
                        }
                    }

                case let .drawGlyph(glyph, transform):
                    tessellateGlyph(
                        glyph,
                        transform: transform,
                        tessellator: tessellator,
                        fontAtlasSlotIndex: &fontAtlasSlotIndex
                    )

                case .commit:
                    // Commit marks end of a draw batch - could be used for flushing
                    break
                }
            }
        }
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
        tessellator: UITessellator,
        fontAtlasSlotIndex: inout Int
    ) {
        let texIndex = findOrAddTexture(
            glyph.textureAtlas,
            in: &renderData.fontAtlases,
            slotIndex: &fontAtlasSlotIndex
        )

        let vertexOffset = UInt32(renderData.glyphVertices.count)
        let vertices = tessellator.tessellateGlyph(
            glyph,
            transform: transform,
            textureIndex: texIndex
        )
        renderData.glyphVertices.append(contentsOf: vertices)

        let indices = tessellator.generateGlyphIndices(vertexOffset: vertexOffset)
        renderData.glyphIndices.append(contentsOf: indices)
    }
}

// MARK: - UIRenderNode

/// Render node for UI rendering in the render graph.
public struct UIRenderNode: RenderNode {

    public enum InputNode {
        public static let view: RenderSlot.Label = "view"
    }

    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]

    public init() {}

    public func execute(
        context: inout Context,
        renderContext: AdaRender.RenderContext
    ) async throws -> [AdaRender.RenderSlotValue] {
        return []
    }
}

// MARK: - UIRenderItem

/// Render item for UI primitives.
public struct UIRenderItem: RenderItem {
    public var sortKey: Float
    public var entity: AdaECS.Entity.ID
    public var drawPass: any AdaRender.DrawPass
    public var batchRange: Range<Int32>? = nil

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
        batchRange: Range<Int32>? = nil
    ) {
        self.sortKey = sortKey
        self.entity = entity
        self.drawPass = drawPass
        self.primitiveType = primitiveType
        self.batchRange = batchRange
    }
}
