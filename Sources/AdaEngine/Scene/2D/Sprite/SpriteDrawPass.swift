//
//  SpriteDrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import Math

struct SpriteVertexData {
    let position: Vector4
    let color: Color
    let textureCoordinate: Vector2
    let textureIndex: Int
}

/// Render draw pass for rendering sprites. Support batching.
public struct SpriteDrawPass: DrawPass {
    
    public func render(in context: Context, item: Transparent2DRenderItem) throws {
        guard let spriteData = context.entity.components[SpriteDataComponent.self] else {
            return
        }
        
        guard let cameraViewUniform = context.view.components[GlobalViewUniformBufferSet.self] else {
            return
        }
        
        context.drawList.pushDebugName("SpriteDrawPass")
        
        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: context.device.currentFrameIndex
        )
        
        if let batchSprite = item.batchEntity.components[BatchComponent.self] {
            batchSprite.textures.enumerated().forEach { (index, texture) in
                context.drawList.bindTexture(texture, at: index)
            }
        }
        
        context.drawList.appendUniformBuffer(uniformBuffer)

        context.drawList.appendVertexBuffer(spriteData.vertexBuffer)
        context.drawList.bindIndexBuffer(spriteData.indexBuffer)
        context.drawList.bindRenderPipeline(item.renderPipeline)
        
        context.drawList.drawIndexed(
            indexCount: item.batchRange?.count ?? 6, // indicies count per quad
            indexBufferOffset: Int(item.batchRange?.lowerBound ?? 0) * 4, // start position must be multiple by 4
            instanceCount: 1
        )
        
        context.drawList.popDebugName()
    }
}

public extension DrawPassId {
    static let sprite = SpriteDrawPass.identifier
}
