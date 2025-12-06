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

struct SpriteVertexData {
    let position: Vector4
    let color: Color
    let textureCoordinate: Vector2
    let textureIndex: Int
}

/// Render draw pass for rendering sprites. Support batching.
public struct SpriteDrawPass: DrawPass {
    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: Transparent2DRenderItem
    ) throws {
        guard
            let cameraViewUniform = view.components[GlobalViewUniformBufferSet.self],
            let spritesData = world.getResource(SpriteDrawData.self)
        else {
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
        guard let batchSprite = world.getEntityByID(item.batchEntity)?.components[TextureBatchComponent.self] else {
            return
        }
        batchSprite.textures.enumerated().forEach { (index, texture) in
            renderEncoder.setFragmentTexture(texture, index: index)
            renderEncoder.setFragmentSamplerState(texture.sampler, index: index)
        }
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: GlobalBufferIndex.viewUniform)
        renderEncoder.setVertexBuffer(spritesData.vertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(spritesData.indexBuffer, indexFormat: .uInt32)
        renderEncoder.setRenderPipelineState(item.renderPipeline)
        renderEncoder.drawIndexed(
            indexCount: item.batchRange?.count ?? 6, // indicies count per quad
            indexBufferOffset: Int(item.batchRange?.lowerBound ?? 0) * 4, // start position must be multiple by 4
            instanceCount: 1
        )
    }
}
