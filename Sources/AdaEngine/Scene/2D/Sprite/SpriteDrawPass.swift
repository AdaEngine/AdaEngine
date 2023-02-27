//
//  SpriteDrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import Math

public struct SpriteDrawPass: DrawPass {
    
    struct SpriteViewUniform {
        let viewMatrix: Transform3D
    }
    
    let uniformBufferSet: UniformBufferSet
    
    public init() {
        uniformBufferSet = RenderEngine.shared.makeUniformBufferSet()
        uniformBufferSet.initBuffers(for: SpriteViewUniform.self, count: 3, binding: 1, set: 0)
    }
    
    public func render(in context: Context, item: Transparent2DRenderItem) throws {
        guard let spriteData = context.entity.components[SpriteDataComponent.self] else {
            return
        }
        
        guard let batchSprite = item.batchEntity.components[BatchComponent.self] else {
            return
        }
        
        guard let cameraViewUniform = context.view.components[ViewUniform.self] else {
            return
        }
        
        let count = item.batchRange?.count ?? 0
        
        let uniform = uniformBufferSet.getBuffer(binding: 1, set: 0, frameIndex: context.device.currentFrameIndex)
        uniform.setData(SpriteViewUniform(viewMatrix: cameraViewUniform.viewProjectionMatrix))
        
        batchSprite.textures.enumerated().forEach { (index, texture) in
            context.drawList.bindTexture(texture, at: index)
        }
        context.drawList.appendUniformBuffer(uniform)
        context.drawList.appendVertexBuffer(spriteData.vertexBuffer)
        context.drawList.bindIndexBuffer(spriteData.indexBuffer)
        context.drawList.bindRenderPipeline(item.renderPipeline)
        
        context.drawList.drawIndexed(indexCount: count, instancesCount: 1)
    }
}
