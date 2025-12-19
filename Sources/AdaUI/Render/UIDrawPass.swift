//
//  UIDrawPass.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 19.12.2025.
//

import AdaECS
import AdaRender
import AdaText
import AdaCorePipelines

// MARK: - UI Draw Data

/// Resource that holds GPU buffers for UI rendering.
public struct UIDrawData: Resource {
    /// Vertex buffer for quads.
    public var quadVertexBuffer: BufferData<QuadVertexData>
    /// Index buffer for quads.
    public var quadIndexBuffer: BufferData<UInt32>

    /// Vertex buffer for circles.
    public var circleVertexBuffer: BufferData<CircleVertexData>
    /// Index buffer for circles.
    public var circleIndexBuffer: BufferData<UInt32>

    /// Vertex buffer for lines.
    public var lineVertexBuffer: BufferData<LineVertexData>
    /// Index buffer for lines.
    public var lineIndexBuffer: BufferData<UInt32>

    /// Vertex buffer for glyphs.
    public var glyphVertexBuffer: BufferData<GlyphVertexData>
    /// Index buffer for glyphs.
    public var glyphIndexBuffer: BufferData<UInt32>

    /// Textures used for quad rendering (max 16 per batch).
    public var textures: [Texture2D] = []

    /// Font atlas textures used for text rendering (max 16 per batch).
    public var fontAtlases: [Texture2D] = []

    public init() {
        self.quadVertexBuffer = BufferData(label: "UI_QuadVertexBuffer", elements: [])
        self.quadIndexBuffer = BufferData(label: "UI_QuadIndexBuffer", elements: [])
        self.circleVertexBuffer = BufferData(label: "UI_CircleVertexBuffer", elements: [])
        self.circleIndexBuffer = BufferData(label: "UI_CircleIndexBuffer", elements: [])
        self.lineVertexBuffer = BufferData(label: "UI_LineVertexBuffer", elements: [])
        self.lineIndexBuffer = BufferData(label: "UI_LineIndexBuffer", elements: [])
        self.glyphVertexBuffer = BufferData(label: "UI_GlyphVertexBuffer", elements: [])
        self.glyphIndexBuffer = BufferData(label: "UI_GlyphIndexBuffer", elements: [])
    }

    /// Clears all vertex, index, and texture data while keeping capacity.
    public mutating func clear() {
        quadVertexBuffer.removeAll()
        quadIndexBuffer.removeAll()
        circleVertexBuffer.removeAll()
        circleIndexBuffer.removeAll()
        lineVertexBuffer.removeAll()
        lineIndexBuffer.removeAll()
        glyphVertexBuffer.removeAll()
        glyphIndexBuffer.removeAll()

        textures.removeAll(keepingCapacity: true)
        fontAtlases.removeAll(keepingCapacity: true)
    }
}

// MARK: - UI Draw Pass

/// Draw pass for rendering UI primitives.
public struct UIDrawPass: DrawPass {
    public typealias Item = UITransparentRenderItem

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: UITransparentRenderItem
    ) throws {
        guard let cameraViewUniform = view.components[GlobalViewUniformBufferSet.self] else {
            return
        }

        let uiDrawData = item.drawData

        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: GlobalBufferIndex.viewUniform)
        renderEncoder.setRenderPipelineState(item.renderPipeline)

        // Determine which primitive type to render based on the entity
        // This is a simplified approach - in a full implementation,
        // you would have separate render items for each primitive type

        // Render quads
        if !uiDrawData.quadIndexBuffer.isEmpty {
            renderQuads(
                renderEncoder: renderEncoder,
                uiDrawData: uiDrawData
            )
        }

        // Render circles
        if !uiDrawData.circleIndexBuffer.isEmpty {
            renderCircles(
                renderEncoder: renderEncoder,
                uiDrawData: uiDrawData
            )
        }

        // Render lines
        if !uiDrawData.lineIndexBuffer.isEmpty {
            renderLines(
                renderEncoder: renderEncoder,
                uiDrawData: uiDrawData
            )
        }

        // Render glyphs
        if !uiDrawData.glyphIndexBuffer.isEmpty {
            renderGlyphs(
                renderEncoder: renderEncoder,
                uiDrawData: uiDrawData
            )
        }
    }

    // MARK: - Private Render Methods

    private func renderQuads(
        renderEncoder: RenderCommandEncoder,
        uiDrawData: UIDrawData
    ) {
        renderEncoder.pushDebugName("UI Quad Render")
        defer { renderEncoder.popDebugName() }

        // Bind textures
        for (index, texture) in uiDrawData.textures.enumerated() {
            renderEncoder.setFragmentTexture(texture, index: index)
            renderEncoder.setFragmentSamplerState(texture.sampler, index: index)
        }

        renderEncoder.setVertexBuffer(uiDrawData.quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.quadIndexBuffer, indexFormat: .uInt32)

        renderEncoder.drawIndexed(
            indexCount: uiDrawData.quadIndexBuffer.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }

    private func renderCircles(
        renderEncoder: RenderCommandEncoder,
        uiDrawData: UIDrawData
    ) {
        renderEncoder.pushDebugName("UI Circle Render")
        defer { renderEncoder.popDebugName() }

        renderEncoder.setVertexBuffer(uiDrawData.circleVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.circleIndexBuffer, indexFormat: .uInt32)

        renderEncoder.drawIndexed(
            indexCount: uiDrawData.circleIndexBuffer.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }

    private func renderLines(
        renderEncoder: RenderCommandEncoder,
        uiDrawData: UIDrawData
    ) {
        renderEncoder.pushDebugName("UI Line Render")
        defer { renderEncoder.popDebugName() }

        renderEncoder.setVertexBuffer(uiDrawData.lineVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.lineIndexBuffer, indexFormat: .uInt32)

        // Lines are rendered using line primitive type configured in the pipeline
        renderEncoder.drawIndexed(
            indexCount: uiDrawData.lineIndexBuffer.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }

    private func renderGlyphs(
        renderEncoder: RenderCommandEncoder,
        uiDrawData: UIDrawData
    ) {
        renderEncoder.pushDebugName("UI Glyph Render")
        defer { renderEncoder.popDebugName() }

        // Bind font atlas textures
        for (index, texture) in uiDrawData.fontAtlases.enumerated() {
            renderEncoder.setFragmentTexture(texture, index: index)
            renderEncoder.setFragmentSamplerState(texture.sampler, index: index)
        }

        renderEncoder.setVertexBuffer(uiDrawData.glyphVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.glyphIndexBuffer, indexFormat: .uInt32)

        renderEncoder.drawIndexed(
            indexCount: uiDrawData.glyphIndexBuffer.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }
}


/// Draw pass for rendering UI primitives.
public struct UIQuadDrawPass: DrawPass {
    public typealias Item = UITransparentRenderItem

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: UITransparentRenderItem
    ) throws {
        guard let cameraViewUniform = view.components[GlobalViewUniformBufferSet.self] else {
            return
        }

        let uiDrawData = item.drawData

        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: GlobalBufferIndex.viewUniform)
        renderEncoder.setRenderPipelineState(item.renderPipeline)

        guard !uiDrawData.quadIndexBuffer.isEmpty else {
            return
        }

        renderEncoder.pushDebugName("UI Quad Render")
        defer { renderEncoder.popDebugName() }

        // Bind textures
        for (index, texture) in uiDrawData.textures.enumerated() {
            renderEncoder.setFragmentTexture(texture, index: index)
            renderEncoder.setFragmentSamplerState(texture.sampler, index: index)
        }

        renderEncoder.setVertexBuffer(uiDrawData.quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.quadIndexBuffer, indexFormat: .uInt32)

        renderEncoder.drawIndexed(
            indexCount: uiDrawData.quadIndexBuffer.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }
}


/// Draw pass for rendering UI primitives.
public struct UICircleDrawPass: DrawPass {
    public typealias Item = UITransparentRenderItem

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: UITransparentRenderItem
    ) throws {
        guard let cameraViewUniform = view.components[GlobalViewUniformBufferSet.self] else {
            return
        }

        let uiDrawData = item.drawData

        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: GlobalBufferIndex.viewUniform)
        renderEncoder.setRenderPipelineState(item.renderPipeline)

        guard !uiDrawData.circleIndexBuffer.isEmpty else {
            return
        }

        renderEncoder.pushDebugName("UI Circle Render")
        defer { renderEncoder.popDebugName() }

        renderEncoder.setVertexBuffer(uiDrawData.circleVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.circleIndexBuffer, indexFormat: .uInt32)

        renderEncoder.drawIndexed(
            indexCount: uiDrawData.circleIndexBuffer.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }
}


/// Draw pass for rendering UI primitives.
public struct UILinesDrawPass: DrawPass {
    public typealias Item = UITransparentRenderItem

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: UITransparentRenderItem
    ) throws {
        guard let cameraViewUniform = view.components[GlobalViewUniformBufferSet.self] else {
            return
        }

        let uiDrawData = item.drawData

        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: GlobalBufferIndex.viewUniform)
        renderEncoder.setRenderPipelineState(item.renderPipeline)

        guard !uiDrawData.lineIndexBuffer.isEmpty else {
            return
        }

        renderEncoder.pushDebugName("UI Line Render")
        defer { renderEncoder.popDebugName() }

        renderEncoder.setVertexBuffer(uiDrawData.lineVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.lineIndexBuffer, indexFormat: .uInt32)

        // Lines are rendered using line primitive type configured in the pipeline
        renderEncoder.drawIndexed(
            indexCount: uiDrawData.lineIndexBuffer.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }
}


/// Draw pass for rendering UI primitives.
public struct UIGlyphDrawPass: DrawPass {
    public typealias Item = UITransparentRenderItem

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: UITransparentRenderItem
    ) throws {
        guard let cameraViewUniform = view.components[GlobalViewUniformBufferSet.self] else {
            return
        }

        let uiDrawData = item.drawData

        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: GlobalBufferIndex.viewUniform)
        renderEncoder.setRenderPipelineState(item.renderPipeline)

        guard !uiDrawData.glyphIndexBuffer.isEmpty else {
            return
        }

        renderEncoder.pushDebugName("UI Glyph Render")
        defer { renderEncoder.popDebugName() }

        // Bind font atlas textures
        for (index, texture) in uiDrawData.fontAtlases.enumerated() {
            renderEncoder.setFragmentTexture(texture, index: index)
            renderEncoder.setFragmentSamplerState(texture.sampler, index: index)
        }

        renderEncoder.setVertexBuffer(uiDrawData.glyphVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.glyphIndexBuffer, indexFormat: .uInt32)

        renderEncoder.drawIndexed(
            indexCount: uiDrawData.glyphIndexBuffer.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }
}
