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
    /// Height map for parallax occlusion mapping, read from the red channel (`1` is the top of the surface, `0` the
    /// deepest point). Use a linear (non-sRGB) texture. Parallax shifts every material texture that shares
    /// ``heightTextureCoordinate``, so the relief stays consistent with color, normal and occlusion maps.
    /// The shader has no free sampler slot, so the height map is read with the base color texture's sampler:
    /// give both the same address and filter modes.
    public var heightTexture: Texture2D? { didSet { uniformRevision &+= 1 } }
    /// Depth of the relief in world units, measured from the top of the surface. `0` disables parallax.
    public var heightScale: Float = 0.05 { didSet { uniformRevision &+= 1 } }
    /// UV set the height map is sampled with.
    public var heightTextureCoordinate: Int = 0 { didSet { uniformRevision &+= 1 } }
    /// Largest number of ray-march steps, used at grazing angles (a quarter of it is used head-on). Clamped to `4...64`.
    public var heightMaxLayers: Int = 32 { didSet { uniformRevision &+= 1 } }
    /// Camera distance in view units beyond which parallax has faded out completely. It fades over the last half.
    public var heightFadeDistance: Float = 30 { didSet { uniformRevision &+= 1 } }
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
    /// Strength of a clear lacquer layer over the surface (`KHR_materials_clearcoat`); 0 turns the layer off.
    public var clearcoatFactor: Float = 0 { didSet { uniformRevision &+= 1 } }
    /// Roughness of the clearcoat layer, independent of the base layer's roughness.
    public var clearcoatRoughnessFactor: Float = 0 { didSet { uniformRevision &+= 1 } }
    /// Color of a soft fabric sheen over the surface (`KHR_materials_sheen`); black turns the layer off.
    public var sheenColorFactor: Vector3 = .zero { didSet { uniformRevision &+= 1 } }
    /// Roughness of the sheen layer.
    public var sheenRoughnessFactor: Float = 0 { didSet { uniformRevision &+= 1 } }
    /// How much highlights stretch (`KHR_materials_anisotropy`, 0 to 1); 0 keeps them round.
    public var anisotropyStrength: Float = 0 { didSet { uniformRevision &+= 1 } }
    /// Rotation of the stretch direction from the surface tangent, in radians.
    public var anisotropyRotation: Float = 0 { didSet { uniformRevision &+= 1 } }

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
