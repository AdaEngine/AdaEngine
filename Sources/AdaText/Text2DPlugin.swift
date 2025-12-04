//
//  Text2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/5/23.
//

import AdaAssets
import AdaApp
import AdaECS
import AdaRender

/// Append text rendering systems to the scene.
public struct TextPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        TextComponent.registerComponent()

        app
            .main
            .insertResource(RenderPipelines<TextPipeline>(configurator: TextPipeline()))
            .addSystem(TextLayoutSystem.self)
    }
}

public struct TextPipeline: RenderPipelineConfigurator {
    private let shader: AssetHandle<ShaderModule>

    public init() {
        self.shader = try! AssetsManager.loadSync(
            ShaderModule.self,
            at: "Assets/text.glsl",
            from: .module
        )
    }

    public func configurate(
        with configuration: RenderPipelineEmptyConfiguration
    ) -> RenderPipelineDescriptor {
        var piplineDesc = RenderPipelineDescriptor()
        piplineDesc.vertex = shader.asset.getShader(for: .vertex)
        piplineDesc.fragment = shader.asset.getShader(for: .fragment)
        piplineDesc.debugName = "Text Pipeline"

        piplineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "position"),
            .attribute(.vector4, name: "foregroundColor"),
            .attribute(.vector4, name: "outlineColor"),
            .attribute(.vector2, name: "textureCoordinate"),
            .attribute(.int, name: "textureIndex")
        ])

        piplineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<GlyphVertexData>.stride
        piplineDesc.colorAttachments = [
            RenderPipelineColorAttachmentDescriptor(
                format: .bgra8,
                isBlendingEnabled: true
            )
        ]
        return piplineDesc
    }
}
