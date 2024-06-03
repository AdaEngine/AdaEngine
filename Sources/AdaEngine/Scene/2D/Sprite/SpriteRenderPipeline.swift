//
//  File.swift
//  
//
//  Created by v.prusakov on 5/5/24.
//

import Foundation

struct SpriteRenderPipeline {

    static let `default` = SpriteRenderPipeline()

    let renderPipeline: RenderPipeline

    private init() {
        let device = RenderEngine.shared

        let quadShader = try! ResourceManager.loadSync("Shaders/Vulkan/quad.glsl", from: .engineBundle) as ShaderModule

        var piplineDesc = RenderPipelineDescriptor()
        piplineDesc.vertex = quadShader.getShader(for: .vertex)
        piplineDesc.fragment = quadShader.getShader(for: .fragment)
        piplineDesc.debugName = "Sprite Pipeline"

        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "a_Position"),
            .attribute(.vector4, name: "a_Color"),
            .attribute(.vector2, name: "a_TexCoordinate"),
            .attribute(.int, name: "a_TexIndex")
        ])

        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<SpriteVertexData>.stride

        piplineDesc.colorAttachments = [ColorAttachmentDescriptor(format: .bgra8, isBlendingEnabled: true)]

        let quadPipeline = device.makeRenderPipeline(from: piplineDesc)

        self.renderPipeline = quadPipeline
    }

}
