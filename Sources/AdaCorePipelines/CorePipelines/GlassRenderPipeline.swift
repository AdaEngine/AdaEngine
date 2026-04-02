//
//  GlassRenderPipeline.swift
//  AdaEngine
//

import AdaAssets
import AdaECS
import AdaRender
import AdaUtils
import Math

/// Vertex data for rendering glass quads.
/// Matches the attribute layout expected by glass.glsl.
public struct GlassVertexData: Sendable {
    /// Position in world space (vec4).
    public let position: Vector4
    /// Optional tint color overlay (vec4). Alpha controls blend strength.
    public let color: Color
    /// Local UV coordinates [0,1] across the quad (vec2).
    public let texCoord: Vector2
    /// Glass visual parameters (vec4):
    /// x = blurRadius (logical pixels), y = cornerRadius (logical pixels),
    /// z = glassTintStrength [0,1], w = edgeShadowStrength [0,1].
    public let glassParams: Vector4
    /// Glass geometry and display info (vec4):
    /// x = halfWidth, y = halfHeight (logical pixels),
    /// z = display scaleFactor, w = opacity [0,1].
    public let glassInfo: Vector4

    public init(
        position: Vector4,
        color: Color,
        texCoord: Vector2,
        glassParams: Vector4,
        glassInfo: Vector4
    ) {
        self.position = position
        self.color = color
        self.texCoord = texCoord
        self.glassParams = glassParams
        self.glassInfo = glassInfo
    }
}

/// Pipeline configurator for rendering glass quads.
public struct GlassPipeline: RenderPipelineConfigurator {
    private let shader: AssetHandle<ShaderModule>

    public init() {
        self.shader = try! AssetsManager.loadSync(
            ShaderModule.self,
            at: "Shaders/glass.glsl",
            from: .module
        )
    }

    public func configurate(
        with configuration: RenderPipelineEmptyConfiguration
    ) -> RenderPipelineDescriptor {
        var pipelineDesc = RenderPipelineDescriptor(vertex: shader.asset.getShader(for: .vertex)!)
        pipelineDesc.fragment = shader.asset.getShader(for: .fragment)
        pipelineDesc.debugName = "Glass Pipeline"

        pipelineDesc.vertexDescriptor.attributes.append([
            .attribute(.vector4, name: "a_Position"),
            .attribute(.vector4, name: "a_Color"),
            .attribute(.vector2, name: "a_TexCoordinate"),
            .attribute(.vector4, name: "a_GlassParams"),
            .attribute(.vector4, name: "a_GlassInfo"),
        ])

        pipelineDesc.vertexDescriptor.layouts[0].stride = MemoryLayout<GlassVertexData>.stride
        pipelineDesc.colorAttachments = [
            RenderPipelineColorAttachmentDescriptor(
                format: .bgra8,
                isBlendingEnabled: true
            )
        ]
        return pipelineDesc
    }
}
