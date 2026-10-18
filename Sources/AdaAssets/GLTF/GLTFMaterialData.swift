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
        /// `KHR_materials_specular` strength and tint of the dielectric reflection. Specular textures are not read.
        public let specularFactor: Float
        public let specularColorFactor: Vector3

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
            specularColorFactor: Vector3 = .one
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
