//
//  File.swift
//  
//
//  Created by v.prusakov on 5/5/24.
//

import AdaAssets
import AdaRender
import Foundation

struct SpriteRenderPipeline: Sendable {

    static let `default` = SpriteRenderPipeline()

    let renderPipeline: RenderPipeline

    private init() {
        let device = RenderEngine.shared.renderDevice
//        let quadShader = try! AssetsManager.loadSync(
//            ShaderModule.self, 
//            at: "Shaders/quad.glsl", 
//            from: .module
//        )

        var piplineDesc = RenderPipelineDescriptor()
//        piplineDesc.vertex = quadShader.asset.getShader(for: .vertex)
//        piplineDesc.fragment = quadShader.asset.getShader(for: .fragment)
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
