//
//  Flat3DPipeline.swift
//  AdaEngine
//
//  Created by Codex on 07/06/26.
//

import AdaAssets
import AdaECS
import AdaRender
import AdaUtils

/// Pipeline configurator for a simple unlit 3D mesh pass.
public struct Flat3DPipeline: RenderPipelineConfigurator {
    private let shader: AssetHandle<ShaderModule>

    public init() {
        self.shader = try! ShaderModule.loadBundled(at: "Shaders/flat3d.glsl", from: .module)
    }

    public func configurate(with configuration: VertexDescriptor) -> RenderPipelineDescriptor {
        var descriptor = RenderPipelineDescriptor(vertex: shader.asset.getShader(for: .vertex)!)
        descriptor.fragment = shader.asset.getShader(for: .fragment)
        descriptor.debugName = "Flat 3D Pipeline"
        descriptor.vertexDescriptor = configuration
        descriptor.depthStencilDescriptor = DepthStencilDescriptor(
            isDepthTestEnabled: true,
            isDepthWriteEnabled: true,
            depthCompareOperator: .less
        )
        descriptor.colorAttachments = [
            RenderPipelineColorAttachmentDescriptor(format: .bgra8)
        ]
        return descriptor
    }
}
