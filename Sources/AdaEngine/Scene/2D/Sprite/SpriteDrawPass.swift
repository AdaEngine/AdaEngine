//
//  SpriteDrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import Math

public struct SpriteDrawPass: DrawPass {
    
    public func render(in context: Context, item: Transparent2DRenderItem) throws {
        guard let spriteData = context.entity.components[SpriteDataComponent.self] else {
            return
        }
        
        guard let batchSprite = item.batchEntity.components[BatchComponent.self] else {
            return
        }
        
        guard let cameraViewUniform = context.view.components[GlobalViewUniformBufferSet.self] else {
            return
        }
        
        guard let count = item.batchRange?.count else {
            return
        }
        
        context.drawList.pushDebugName("SpriteDrawPass")
        
        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(binding: BufferIndex.baseUniform, set: 0, frameIndex: context.device.currentFrameIndex)
        context.drawList.appendUniformBuffer(uniformBuffer)
        
        batchSprite.textures.enumerated().forEach { (index, texture) in
            context.drawList.bindTexture(texture, at: index)
        }
        context.drawList.appendVertexBuffer(spriteData.vertexBuffer)
        context.drawList.bindIndexBuffer(spriteData.indexBuffer)
        context.drawList.bindRenderPipeline(item.renderPipeline)
        
        context.drawList.drawIndexed(indexCount: count, instancesCount: 1)
        
        context.drawList.popDebugName()
    }
}
