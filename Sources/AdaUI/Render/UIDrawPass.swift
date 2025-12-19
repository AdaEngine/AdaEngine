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
}

// MARK: - UI Draw Pass

/// Draw pass for rendering UI primitives.
public struct UIDrawPass: DrawPass {
    public typealias Item = Transparent2DRenderItem

    public init() {}

    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: Transparent2DRenderItem
    ) throws {
        guard let cameraViewUniform = view.components[GlobalViewUniformBufferSet.self] else {
            return
        }

        guard let uiDrawData = world.getResource(UIDrawData.self) else {
            return
        }

        guard let uiRenderData = world.getResource(UIRenderData.self) else {
            return
        }

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
        if !uiRenderData.quadIndices.isEmpty {
            renderQuads(
                renderEncoder: renderEncoder,
                uiDrawData: uiDrawData,
                uiRenderData: uiRenderData
            )
        }

        // Render circles
        if !uiRenderData.circleIndices.isEmpty {
            renderCircles(
                renderEncoder: renderEncoder,
                uiDrawData: uiDrawData,
                uiRenderData: uiRenderData
            )
        }

        // Render lines
        if !uiRenderData.lineIndices.isEmpty {
            renderLines(
                renderEncoder: renderEncoder,
                uiDrawData: uiDrawData,
                uiRenderData: uiRenderData
            )
        }

        // Render glyphs
        if !uiRenderData.glyphIndices.isEmpty {
            renderGlyphs(
                renderEncoder: renderEncoder,
                uiDrawData: uiDrawData,
                uiRenderData: uiRenderData
            )
        }
    }

    // MARK: - Private Render Methods

    private func renderQuads(
        renderEncoder: RenderCommandEncoder,
        uiDrawData: UIDrawData,
        uiRenderData: UIRenderData
    ) {
        renderEncoder.pushDebugName("UI Quad Render")
        defer { renderEncoder.popDebugName() }

        // Bind textures
        for (index, texture) in uiRenderData.textures.enumerated() {
            renderEncoder.setFragmentTexture(texture, index: index)
            renderEncoder.setFragmentSamplerState(texture.sampler, index: index)
        }

        renderEncoder.setVertexBuffer(uiDrawData.quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.quadIndexBuffer, indexFormat: .uInt32)

        renderEncoder.drawIndexed(
            indexCount: uiRenderData.quadIndices.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }

    private func renderCircles(
        renderEncoder: RenderCommandEncoder,
        uiDrawData: UIDrawData,
        uiRenderData: UIRenderData
    ) {
        renderEncoder.pushDebugName("UI Circle Render")
        defer { renderEncoder.popDebugName() }

        renderEncoder.setVertexBuffer(uiDrawData.circleVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.circleIndexBuffer, indexFormat: .uInt32)

        renderEncoder.drawIndexed(
            indexCount: uiRenderData.circleIndices.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }

    private func renderLines(
        renderEncoder: RenderCommandEncoder,
        uiDrawData: UIDrawData,
        uiRenderData: UIRenderData
    ) {
        renderEncoder.pushDebugName("UI Line Render")
        defer { renderEncoder.popDebugName() }

        renderEncoder.setVertexBuffer(uiDrawData.lineVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.lineIndexBuffer, indexFormat: .uInt32)

        // Lines are rendered using line primitive type configured in the pipeline
        renderEncoder.drawIndexed(
            indexCount: uiRenderData.lineIndices.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }

    private func renderGlyphs(
        renderEncoder: RenderCommandEncoder,
        uiDrawData: UIDrawData,
        uiRenderData: UIRenderData
    ) {
        renderEncoder.pushDebugName("UI Glyph Render")
        defer { renderEncoder.popDebugName() }

        // Bind font atlas textures
        for (index, texture) in uiRenderData.fontAtlases.enumerated() {
            renderEncoder.setFragmentTexture(texture, index: index)
            renderEncoder.setFragmentSamplerState(texture.sampler, index: index)
        }

        renderEncoder.setVertexBuffer(uiDrawData.glyphVertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(uiDrawData.glyphIndexBuffer, indexFormat: .uInt32)

        renderEncoder.drawIndexed(
            indexCount: uiRenderData.glyphIndices.count,
            indexBufferOffset: 0,
            instanceCount: 1
        )
    }
}

// MARK: - UI Buffer Update System

/// System that updates GPU buffers from tessellated UI data.
@PlainSystem
public struct UIBufferUpdateSystem {

    @Res<UIRenderData>
    private var renderData

    @ResMut<UIDrawData>
    private var drawData

    @Res<RenderDeviceHandler>
    private var renderDevice

    public init(world: World) {}

    public func update(context: UpdateContext) {
        let device = renderDevice.renderDevice

        // Update quad buffers
        updateBuffer(
            &drawData.quadVertexBuffer,
            with: renderData.quadVertices,
            device: device
        )
        updateBuffer(
            &drawData.quadIndexBuffer,
            with: renderData.quadIndices,
            device: device
        )

        // Update circle buffers
        updateBuffer(
            &drawData.circleVertexBuffer,
            with: renderData.circleVertices,
            device: device
        )
        updateBuffer(
            &drawData.circleIndexBuffer,
            with: renderData.circleIndices,
            device: device
        )

        // Update line buffers
        updateBuffer(
            &drawData.lineVertexBuffer,
            with: renderData.lineVertices,
            device: device
        )
        updateBuffer(
            &drawData.lineIndexBuffer,
            with: renderData.lineIndices,
            device: device
        )

        // Update glyph buffers
        updateBuffer(
            &drawData.glyphVertexBuffer,
            with: renderData.glyphVertices,
            device: device
        )
        updateBuffer(
            &drawData.glyphIndexBuffer,
            with: renderData.glyphIndices,
            device: device
        )
    }

    private func updateBuffer<T>(
        _ bufferData: inout BufferData<T>,
        with elements: [T],
        device: RenderDevice
    ) {
        bufferData.elements = elements

        guard !elements.isEmpty else {
            return
        }

        bufferData.write(to: device)
    }
}
