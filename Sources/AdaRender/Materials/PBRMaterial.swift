//
//  PBRMaterial.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaAssets
import AdaUtils
import Math

/// Scales, then rotates, then offsets the UV coordinates a PBR texture is sampled with (glTF `KHR_texture_transform`).
public struct PBRTextureTransform: Sendable, Equatable {
    public var offset: Vector2
    /// Counter-clockwise rotation in radians.
    public var rotation: Float
    public var scale: Vector2

    public static let identity = PBRTextureTransform()

    public init(offset: Vector2 = .zero, rotation: Float = 0, scale: Vector2 = .one) {
        self.offset = offset
        self.rotation = rotation
        self.scale = scale
    }
}

/// A material that uses Physically Based Rendering (PBR) to define its appearance.
public class PBRMaterial: Material, @unchecked Sendable {
    public var baseColorFactor: Vector4 = .one { didSet { uniformRevision &+= 1 } }
    public var baseColorTexture: Texture2D?
    public var metallicFactor: Float = 1
    public var roughnessFactor: Float = 1
    public var metallicRoughnessTexture: Texture2D?
    public var normalTexture: Texture2D?
    public var emissiveTexture: Texture2D?
    public var emissiveStrength: Float = 0
    public var emissiveFactor: Vector3 = .one { didSet { uniformRevision &+= 1 } }
    public var occlusionTexture: Texture2D? { didSet { uniformRevision &+= 1 } }
    public var occlusionStrength: Float = 1 { didSet { uniformRevision &+= 1 } }
    public var normalScale: Float = 1 { didSet { uniformRevision &+= 1 } }
    public enum AlphaMode: UInt8, Sendable { case opaque, mask, blend }
    public var alphaMode: AlphaMode = .opaque { didSet { uniformRevision &+= 1 } }
    public var alphaCutoff: Float = 0.5 { didSet { uniformRevision &+= 1 } }
    public var doubleSided = false { didSet { uniformRevision &+= 1 } }
    /// UV sets for base color, metallic/roughness, normal, occlusion, and emission.
    public var textureCoordinates: [Int] = [0, 0, 0, 0, 0] { didSet { uniformRevision &+= 1 } }
    /// A negative value emits everywhere. Non-negative values fade emission
    /// out as direct illumination rises above this threshold.
    public var emissiveLightThreshold: Float = -1
    /// UV transforms for base color, metallic/roughness, normal, occlusion, and emission.
    public var textureTransforms: [PBRTextureTransform] = Array(repeating: .identity, count: 5) { didSet { uniformRevision &+= 1 } }
    /// Index of refraction of the dielectric layer. The default 1.5 gives the usual 4% reflectance at normal incidence.
    public var ior: Float = 1.5 { didSet { uniformRevision &+= 1 } }
    /// Strength of the dielectric specular reflection (`KHR_materials_specular`).
    public var specularFactor: Float = 1 { didSet { uniformRevision &+= 1 } }
    /// Tint of the dielectric specular reflection (`KHR_materials_specular`).
    public var specularColorFactor: Vector3 = .one { didSet { uniformRevision &+= 1 } }

    /// Changes whenever parameters in the shared PBR uniform snapshot are edited.
    @_spi(Internal) public private(set) var uniformRevision: UInt64 = 0

    public init() {
        // FIXME: (Vlad) We need a way to specify the shader for PBR material.
        // For now we use a dummy shader source.
        super.init(shaderSource: ShaderSource())
    }

    public required init(from assetDecoder: AssetDecoder) throws {
        let shaderSource = try ShaderSource(from: assetDecoder)
        super.init(shaderSource: shaderSource)
    }

    override public func collectDefines(for _: VertexDescriptor, keys _: Set<String>) -> [ShaderDefine] {
        var defines: [ShaderDefine] = []
        if baseColorTexture != nil {
            defines.append(ShaderDefine(name: "HAS_BASE_COLOR_TEXTURE", value: "1"))
        }
        if metallicRoughnessTexture != nil {
            defines.append(ShaderDefine(name: "HAS_METALLIC_ROUGHNESS_TEXTURE", value: "1"))
        }
        if normalTexture != nil {
            defines.append(ShaderDefine(name: "HAS_NORMAL_TEXTURE", value: "1"))
        }
        if emissiveTexture != nil {
            defines.append(ShaderDefine(name: "HAS_EMISSIVE_TEXTURE", value: "1"))
        }
        return defines
    }
}
