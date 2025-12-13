//
//  SpriteDrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import AdaECS
import AdaRender
import AdaUtils
import Math

public struct SpriteVertexData: Sendable {
    public let position: Vector4
    public let color: Color
    public let textureCoordinate: Vector2

    public init(position: Vector4, color: Color, textureCoordinate: Vector2) {
        self.position = position
        self.color = color
        self.textureCoordinate = textureCoordinate
    }
}

/// Render draw pass for rendering sprites. Support batching.
///
/// Batching works by grouping sprites with the same texture together
/// and drawing them with a single draw call. Each sprite has pre-transformed
/// vertices in the vertex buffer, allowing efficient rendering without
/// per-instance data.
public struct SpriteDrawPass: DrawPass {
    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: Transparent2DRenderItem
    ) throws {
        guard
            let cameraViewUniform = view.components[GlobalViewUniformBufferSet.self],
            let spritesData = world.getResource(SpriteDrawData.self),
            let spriteBatches = world.getResource(SpriteBatches.self)
        else {
            return
        }

        guard let batch = spriteBatches.batches[item.entity] else {
            return
        }

        renderEncoder.pushDebugName("SpriteDrawPass")
        defer {
            renderEncoder.popDebugName()
        }

        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        renderEncoder.setFragmentTexture(batch.texture, index: 0)
        renderEncoder.setFragmentSamplerState(batch.texture.sampler, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: GlobalBufferIndex.viewUniform)
        renderEncoder.setVertexBuffer(spritesData.vertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(spritesData.indexBuffer, indexFormat: .uInt32)
        renderEncoder.setRenderPipelineState(item.renderPipeline)
        
        let instanceCount = Int(batch.range.upperBound - batch.range.lowerBound)
        let indexBufferOffset = Int(batch.range.lowerBound) * MemoryLayout<UInt32>.stride
        renderEncoder.drawIndexed(
            indexCount: 6 * instanceCount,
            indexBufferOffset: 6 * indexBufferOffset,
            instanceCount: instanceCount
        )
    }
}
