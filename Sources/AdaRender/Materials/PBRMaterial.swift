//
//  PBRMaterial.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaAssets
import AdaUtils
import Math

/// A material that uses Physically Based Rendering (PBR) to define its appearance.
public class PBRMaterial: Material, @unchecked Sendable {
    public var baseColorFactor: Vector4 = .one
    public var baseColorTexture: Texture2D?
    public var metallicFactor: Float = 1
    public var roughnessFactor: Float = 1
    public var metallicRoughnessTexture: Texture2D?
    public var normalTexture: Texture2D?
    
    public init() {
        // FIXME: (Vlad) We need a way to specify the shader for PBR material.
        // For now we use a dummy shader source.
        super.init(shaderSource: ShaderSource())
    }
    
    public required init(from assetDecoder: AssetDecoder) throws {
        let shaderSource = try ShaderSource(from: assetDecoder)
        super.init(shaderSource: shaderSource)
    }
    
    public override func collectDefines(for vertexDescriptor: VertexDescriptor, keys: Set<String>) -> [ShaderDefine] {
        var defines: [ShaderDefine] = []
        if self.baseColorTexture != nil {
            defines.append(ShaderDefine(name: "HAS_BASE_COLOR_TEXTURE", value: "1"))
        }
        if self.metallicRoughnessTexture != nil {
            defines.append(ShaderDefine(name: "HAS_METALLIC_ROUGHNESS_TEXTURE", value: "1"))
        }
        if self.normalTexture != nil {
            defines.append(ShaderDefine(name: "HAS_NORMAL_TEXTURE", value: "1"))
        }
        return defines
    }
}
