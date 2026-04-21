//
//  PBRMaterial.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import Math
import AdaAssets
import AdaUtils

/// A material that uses Physically Based Rendering (PBR) to define its appearance.
public class PBRMaterial: Material, @unchecked Sendable {
    
    public var baseColorFactor: Vector4 {
        get { self.getValue(for: "u_BaseColorFactor", type: Vector4.self) ?? .one }
        set { self.setValue(newValue, for: "u_BaseColorFactor") }
    }
    
    public var baseColorTexture: Texture2D? {
        get { self.getTexture(for: "u_BaseColorTexture")?.texture as? Texture2D }
        set { 
            if let newValue {
                self.setTexture(MaterialTexture(texture: newValue, samplerName: "default"), for: "u_BaseColorTexture")
            }
        }
    }
    
    public var metallicFactor: Float {
        get { self.getValue(for: "u_MetallicFactor", type: Float.self) ?? 1.0 }
        set { self.setValue(newValue, for: "u_MetallicFactor") }
    }
    
    public var roughnessFactor: Float {
        get { self.getValue(for: "u_RoughnessFactor", type: Float.self) ?? 1.0 }
        set { self.setValue(newValue, for: "u_RoughnessFactor") }
    }
    
    public var metallicRoughnessTexture: Texture2D? {
        get { self.getTexture(for: "u_MetallicRoughnessTexture")?.texture as? Texture2D }
        set { 
            if let newValue {
                self.setTexture(MaterialTexture(texture: newValue, samplerName: "default"), for: "u_MetallicRoughnessTexture")
            }
        }
    }
    
    public var normalTexture: Texture2D? {
        get { self.getTexture(for: "u_NormalTexture")?.texture as? Texture2D }
        set { 
            if let newValue {
                self.setTexture(MaterialTexture(texture: newValue, samplerName: "default"), for: "u_NormalTexture")
            }
        }
    }
    
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
