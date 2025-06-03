//
//  File.swift
//  
//
//  Created by v.prusakov on 5/5/24.
//

import AdaECS
import AdaAssets
import AdaRender
import Foundation

struct SpriteRenderPipeline: Resource {
    let renderPipeline: RenderPipeline

    init() {
        let device = RenderEngine.shared.renderDevice
        let spriteShader = try! AssetsManager.loadSync(
            ShaderModule.self,
            at: "Assets/sprite.glsl",
            from: .module
        )

        var piplineDesc = RenderPipelineDescriptor()
        piplineDesc.vertex = spriteShader.asset.getShader(for: .vertex)
        piplineDesc.fragment = spriteShader.asset.getShader(for: .fragment)
        piplineDesc.debugName = "Sprite Pipeline"
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "a_Position"),
            .attribute(.vector4, name: "a_Color"),
            .attribute(.vector2, name: "a_TexCoordinate"),
            .attribute(.int, name: "a_TexIndex")
        ])

        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<SpriteVertexData>.stride
        piplineDesc.colorAttachments = [ColorAttachmentDescriptor(format: .bgra8, isBlendingEnabled: true)]
        let quadPipeline = device.createRenderPipeline(from: piplineDesc)
        self.renderPipeline = quadPipeline
    }
}
