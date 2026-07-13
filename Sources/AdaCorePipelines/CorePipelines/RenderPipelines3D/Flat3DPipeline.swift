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
import Math

/// Per-instance data consumed by the flat 3D vertex pipeline.
public struct Flat3DInstanceData: Sendable {
    public let modelMatrix: Transform3D
    public let color: Vector4
    public let material: Vector4

    public init(modelMatrix: Transform3D, color: Vector4, material: Vector4) {
        self.modelMatrix = modelMatrix
        self.color = color
        self.material = material
    }
}

/// Pipeline configurator for a simple unlit 3D mesh pass.
public struct Flat3DPipeline: RenderPipelineConfigurator {
    private let shader: AssetHandle<ShaderModule>

    public init() {
        self.shader = try! ShaderModule.loadBundled(at: "Shaders/flat3d.glsl", from: .module)
    }

    public func configurate(with configuration: VertexDescriptor) -> RenderPipelineDescriptor {
        var configuration = configuration
        configuration.attributes[2] = .attribute(.vector4, name: "instanceModel0", bufferIndex: 3, offset: 0)
        configuration.attributes[3] = .attribute(.vector4, name: "instanceModel1", bufferIndex: 3, offset: 16)
        configuration.attributes[4] = .attribute(.vector4, name: "instanceModel2", bufferIndex: 3, offset: 32)
        configuration.attributes[5] = .attribute(.vector4, name: "instanceModel3", bufferIndex: 3, offset: 48)
        configuration.attributes[6] = .attribute(.vector4, name: "instanceColor", bufferIndex: 3, offset: 64)
        configuration.attributes[7] = .attribute(.vector4, name: "instanceMaterial", bufferIndex: 3, offset: 80)
        configuration.layouts[3] = VertexDescriptor.Layout(
            stride: MemoryLayout<Flat3DInstanceData>.stride,
            stepFunction: .perInstance
        )

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
            RenderPipelineColorAttachmentDescriptor(format: .bgra8),
            RenderPipelineColorAttachmentDescriptor(format: .rgba_16f),
            RenderPipelineColorAttachmentDescriptor(format: .rgba_16f)
        ]
        return descriptor
    }
}
