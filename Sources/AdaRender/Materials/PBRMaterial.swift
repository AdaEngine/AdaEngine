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
