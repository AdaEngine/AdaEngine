//
//  File.swift
//  
//
//  Created by v.prusakov on 5/5/24.
//

import AdaECS
import AdaAssets
import AdaRender

public struct SpriteRenderPipeline: RenderPipelineConfigurator {
    public let spriteShader: AssetHandle<ShaderModule>

    public init() {
        self.spriteShader = try! AssetsManager.loadSync(
            ShaderModule.self,
            at: "Assets/sprite.glsl",
            from: .module
        )
    }
}

extension SpriteRenderPipeline: WorldInitable {
    public init(from world: World) {
        self = Self.init()
    }
}

extension SpriteRenderPipeline {
    public func configurate(with configuration: RenderPipelineEmptyConfiguration) -> RenderPipelineDescriptor {
        var piplineDesc = RenderPipelineDescriptor()
        piplineDesc.vertex = spriteShader.asset.getShader(for: .vertex)
        piplineDesc.fragment = spriteShader.asset.getShader(for: .fragment)
        piplineDesc.debugName = "Sprite Pipeline"
        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "a_Position"),
            .attribute(.vector4, name: "a_Color"),
            .attribute(.vector2, name: "a_TexCoordinate"),
        ])

        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<SpriteVertexData>.stride
        piplineDesc.colorAttachments = [RenderPipelineColorAttachmentDescriptor(format: .bgra8, isBlendingEnabled: true)]
        return piplineDesc
    }
}
