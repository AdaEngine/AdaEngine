//
//  UIRenderData.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 19.12.2025.
//

import AdaECS
import AdaRender
import AdaCorePipelines
import AdaText

/// Resource that holds tessellated vertex and index data for UI rendering.
/// This data is populated by `UIRenderTesselationSystem` and consumed by `UIDrawPass`.
public struct UIRenderData: Resource {

    // MARK: - Vertex Data

    /// Vertices for rendering quads.
    public var quadVertices: [QuadVertexData] = []

    /// Vertices for rendering circles.
    public var circleVertices: [CircleVertexData] = []

    /// Vertices for rendering lines.
    public var lineVertices: [LineVertexData] = []

    /// Vertices for rendering text glyphs.
    public var glyphVertices: [GlyphVertexData] = []

    // MARK: - Index Data

    /// Indices for rendering quads (6 indices per quad).
    public var quadIndices: [UInt32] = []

    /// Indices for rendering circles (6 indices per circle quad).
    public var circleIndices: [UInt32] = []

    /// Indices for rendering lines (2 indices per line).
    public var lineIndices: [UInt32] = []

    /// Indices for rendering glyphs (6 indices per glyph).
    public var glyphIndices: [UInt32] = []

    // MARK: - Textures

    /// Textures used for quad rendering (max 16 per batch).
    public var textures: [Texture2D] = []

    /// Font atlas textures used for text rendering (max 16 per batch).
    public var fontAtlases: [Texture2D] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Methods

    /// Clears all vertex, index, and texture data while keeping capacity.
    public mutating func clear() {
        quadVertices.removeAll(keepingCapacity: true)
        circleVertices.removeAll(keepingCapacity: true)
        lineVertices.removeAll(keepingCapacity: true)
        glyphVertices.removeAll(keepingCapacity: true)

        quadIndices.removeAll(keepingCapacity: true)
        circleIndices.removeAll(keepingCapacity: true)
        lineIndices.removeAll(keepingCapacity: true)
        glyphIndices.removeAll(keepingCapacity: true)

        textures.removeAll(keepingCapacity: true)
        fontAtlases.removeAll(keepingCapacity: true)
    }
}
