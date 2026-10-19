import Math

public extension GLTFImportResult {
    enum AlphaMode: String, Sendable {
        case opaque = "OPAQUE"
        case mask = "MASK"
        case blend = "BLEND"
    }

    /// `KHR_texture_transform`: the UV of a texture is scaled, then rotated (counter-clockwise, radians), then offset.
    struct TextureTransform: Sendable, Equatable {
        public var offset: Vector2
        public var rotation: Float
        public var scale: Vector2

        public static let identity = TextureTransform()

        public init(offset: Vector2 = .zero, rotation: Float = 0, scale: Vector2 = .one) {
            self.offset = offset
            self.rotation = rotation
            self.scale = scale
        }
    }

    /// A texture used by a material extension: which texture, the UV set and transform it is read with, and a scale
    /// (only the clearcoat normal map has one).
    struct TextureReference: Sendable, Equatable {
        public let index: Int
        public let texCoord: Int
        public let transform: TextureTransform
        public let scale: Float

        public init(index: Int, texCoord: Int = 0, transform: TextureTransform = .identity, scale: Float = 1) {
            self.index = index
            self.texCoord = texCoord
            self.transform = transform
            self.scale = scale
        }
    }

    /// Textures read by `KHR_materials_clearcoat`, `KHR_materials_sheen`, `KHR_materials_anisotropy` and
    /// `KHR_materials_specular`. Channels follow the extension texts: clearcoat in red, clearcoat roughness in green,
    /// sheen color in RGB (sRGB), sheen roughness in alpha, anisotropy direction in RG and strength in blue, specular
    /// strength in alpha and specular color in RGB (sRGB).
    struct LayerTextures: Sendable, Equatable {
        public var clearcoat: TextureReference?
        public var clearcoatRoughness: TextureReference?
        public var clearcoatNormal: TextureReference?
        public var sheenColor: TextureReference?
        public var sheenRoughness: TextureReference?
        public var anisotropy: TextureReference?
        public var specular: TextureReference?
        public var specularColor: TextureReference?

        public init(
            clearcoat: TextureReference? = nil,
            clearcoatRoughness: TextureReference? = nil,
            clearcoatNormal: TextureReference? = nil,
            sheenColor: TextureReference? = nil,
            sheenRoughness: TextureReference? = nil,
            anisotropy: TextureReference? = nil,
            specular: TextureReference? = nil,
            specularColor: TextureReference? = nil
        ) {
            self.clearcoat = clearcoat
            self.clearcoatRoughness = clearcoatRoughness
            self.clearcoatNormal = clearcoatNormal
            self.sheenColor = sheenColor
            self.sheenRoughness = sheenRoughness
            self.anisotropy = anisotropy
            self.specular = specular
            self.specularColor = specularColor
        }
    }

    /// glTF metallic/roughness material values; color factors are linear.
    struct Material: Sendable {
        public let name: String?
        public let baseColorFactor: Vector4
        public let baseColorTextureIndex: Int?
        public let metallicFactor: Float
        public let roughnessFactor: Float
        public let metallicRoughnessTextureIndex: Int?
        public let normalTextureIndex: Int?
        public let normalScale: Float
        public let occlusionTextureIndex: Int?
        public let occlusionStrength: Float
        public let emissiveTextureIndex: Int?
        public let emissiveFactor: Vector3
        public let emissiveStrength: Float
        public let alphaMode: AlphaMode
        public let alphaCutoff: Float
        public let doubleSided: Bool
        /// UV set indices for base color, metallic/roughness, normal, occlusion, emission.
        public let textureCoordinates: [Int]
        /// `KHR_texture_transform` for base color, metallic/roughness, normal, occlusion, emission.
        public let textureTransforms: [TextureTransform]
        /// `KHR_materials_ior`. The glTF default is 1.5, which gives the 4% dielectric reflectance.
        public let ior: Float
        /// `KHR_materials_specular` strength and tint of the dielectric reflection. Specular textures are in `layerTextures`.
        public let specularFactor: Float
        public let specularColorFactor: Vector3
        /// `KHR_materials_clearcoat` strength and roughness. Clearcoat textures are in `layerTextures`.
        public let clearcoatFactor: Float
        public let clearcoatRoughnessFactor: Float
        /// `KHR_materials_sheen` color (linear) and roughness. Sheen textures are in `layerTextures`.
        public let sheenColorFactor: Vector3
        public let sheenRoughnessFactor: Float
        /// `KHR_materials_anisotropy` strength and rotation. The anisotropy texture is in `layerTextures`.
        public let anisotropyStrength: Float
        public let anisotropyRotation: Float
        /// The textures of the extensions above.
        public let layerTextures: LayerTextures

        public init(
            name: String?,
            baseColorFactor: Vector4,
            baseColorTextureIndex: Int?,
            metallicFactor: Float,
            roughnessFactor: Float,
            metallicRoughnessTextureIndex: Int?,
            normalTextureIndex: Int?,
            normalScale: Float = 1,
            occlusionTextureIndex: Int? = nil,
            occlusionStrength: Float = 1,
            emissiveTextureIndex: Int? = nil,
            emissiveFactor: Vector3 = .zero,
            emissiveStrength: Float = 1,
            alphaMode: AlphaMode = .opaque,
            alphaCutoff: Float = 0.5,
            doubleSided: Bool = false,
            textureCoordinates: [Int] = [0, 0, 0, 0, 0],
            textureTransforms: [TextureTransform] = Array(repeating: .identity, count: 5),
            ior: Float = 1.5,
            specularFactor: Float = 1,
            specularColorFactor: Vector3 = .one,
            clearcoatFactor: Float = 0,
            clearcoatRoughnessFactor: Float = 0,
            sheenColorFactor: Vector3 = .zero,
            sheenRoughnessFactor: Float = 0,
            anisotropyStrength: Float = 0,
            anisotropyRotation: Float = 0,
            layerTextures: LayerTextures = LayerTextures()
        ) {
            self.name = name
            self.baseColorFactor = baseColorFactor
            self.baseColorTextureIndex = baseColorTextureIndex
            self.metallicFactor = metallicFactor
            self.roughnessFactor = roughnessFactor
            self.metallicRoughnessTextureIndex = metallicRoughnessTextureIndex
            self.normalTextureIndex = normalTextureIndex
            self.normalScale = normalScale
            self.occlusionTextureIndex = occlusionTextureIndex
            self.occlusionStrength = occlusionStrength
            self.emissiveTextureIndex = emissiveTextureIndex
            self.emissiveFactor = emissiveFactor
            self.emissiveStrength = emissiveStrength
            self.alphaMode = alphaMode
            self.alphaCutoff = alphaCutoff
            self.doubleSided = doubleSided
            self.textureCoordinates = textureCoordinates
            self.textureTransforms = textureTransforms
            self.ior = ior
            self.specularFactor = specularFactor
            self.specularColorFactor = specularColorFactor
            self.clearcoatFactor = clearcoatFactor
            self.clearcoatRoughnessFactor = clearcoatRoughnessFactor
            self.sheenColorFactor = sheenColorFactor
            self.sheenRoughnessFactor = sheenRoughnessFactor
            self.anisotropyStrength = anisotropyStrength
            self.anisotropyRotation = anisotropyRotation
            self.layerTextures = layerTextures
        }
    }

    struct Sampler: Sendable {
        public let minFilter: Int
        public let magFilter: Int
        public let wrapS: Int
        public let wrapT: Int

        public init(minFilter: Int = 9987, magFilter: Int = 9729, wrapS: Int = 10497, wrapT: Int = 10497) {
            self.minFilter = minFilter
            self.magFilter = magFilter
            self.wrapS = wrapS
            self.wrapT = wrapT
        }
    }
}
