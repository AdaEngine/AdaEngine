import AdaECS
@_spi(Internal) import AdaRender
import Math

/// One texture slot's UV transform: the first vector is the row-major 2x2 matrix, the second holds the offset.
public struct PBR3DTextureTransform: Sendable, Equatable {
    public let matrix: Vector4
    public let offset: Vector4

    init(_ transform: PBRTextureTransform?) {
        let transform = transform ?? .identity
        // glTF: uv' = T * R * S * uv with R = [[cos, sin], [-sin, cos]].
        let cosine = Math.cos(transform.rotation)
        let sine = Math.sin(transform.rotation)
        matrix = Vector4(
            cosine * transform.scale.x, sine * transform.scale.y,
            -sine * transform.scale.x, cosine * transform.scale.y
        )
        offset = Vector4(transform.offset.x, transform.offset.y, 0, 0)
    }
}

/// Per-draw material parameters; vertex instance data retains color and metal/rough factors.
public struct PBR3DUniform: Sendable, Equatable {
    public let emissiveFactor: Vector4
    public let properties: Vector4
    public let flags: Vector4
    public let coordinates: Vector4
    public let emission: Vector4
    /// UV transforms for base color, metallic/roughness, normal, occlusion and emission, in that order.
    public let transform0: PBR3DTextureTransform
    public let transform1: PBR3DTextureTransform
    public let transform2: PBR3DTextureTransform
    public let transform3: PBR3DTextureTransform
    public let transform4: PBR3DTextureTransform
    /// RGB is the reflectance of a non-metal at normal incidence, from the index of refraction and `KHR_materials_specular`.
    public let dielectric: Vector4

    public init(material: PBRMaterial?, descriptor _: VertexDescriptor) {
        func coordinate(_ slot: Int) -> Int {
            guard let material, material.textureCoordinates.indices.contains(slot) else {
                return 0
            }
            return material.textureCoordinates[slot]
        }
        func transform(_ slot: Int) -> PBR3DTextureTransform {
            PBR3DTextureTransform(material?.textureTransforms.indices.contains(slot) == true ? material?.textureTransforms[slot] : nil)
        }
        emissiveFactor = Vector4(material?.emissiveFactor ?? .one, 0)
        properties = Vector4(material?.normalScale ?? 1, material?.occlusionStrength ?? 1, material?.alphaCutoff ?? 0.5, Float(material?.alphaMode.rawValue ?? 0))
        flags = Vector4(material?.doubleSided ?? true ? 1 : 0, material?.occlusionTexture != nil ? 1 : 0, 0, 0)
        coordinates = Vector4(Float(coordinate(0)), Float(coordinate(1)), Float(coordinate(2)), Float(coordinate(3)))
        emission = Vector4(Float(coordinate(4)), material?.baseColorFactor.w ?? 1, 1, 0)
        transform0 = transform(0)
        transform1 = transform(1)
        transform2 = transform(2)
        transform3 = transform(3)
        transform4 = transform(4)
        dielectric = Vector4(Self.dielectricReflectance(material), 0)
    }

    /// Reflectance at normal incidence of the dielectric layer: ((ior - 1) / (ior + 1))^2 tinted and scaled by the
    /// specular parameters, capped at 1. The defaults give exactly 0.04.
    static func dielectricReflectance(_ material: PBRMaterial?) -> Vector3 {
        let ior = material.map { $0.ior.isFinite ? max($0.ior, 1) : 1.5 } ?? 1.5
        let base = ((ior - 1) / (ior + 1)) * ((ior - 1) / (ior + 1))
        let strength = material.map { $0.specularFactor.isFinite ? max($0.specularFactor, 0) : 1 } ?? 1
        let tint = material?.specularColorFactor ?? .one
        func channel(_ value: Float) -> Float {
            min(base * (value.isFinite ? max(value, 0) : 1), 1) * strength
        }
        return Vector3(channel(tint.x), channel(tint.y), channel(tint.z))
    }

    /// A bit-exact view of every field, so equal material values share one buffer even for -0 and NaN.
    var bitPatterns: [SIMD4<UInt32>] {
        func bits(_ vector: Vector4) -> SIMD4<UInt32> {
            SIMD4(vector.x.bitPattern, vector.y.bitPattern, vector.z.bitPattern, vector.w.bitPattern)
        }
        return [
            bits(emissiveFactor), bits(properties), bits(flags), bits(coordinates), bits(emission),
            bits(transform0.matrix), bits(transform0.offset), bits(transform1.matrix), bits(transform1.offset),
            bits(transform2.matrix), bits(transform2.offset), bits(transform3.matrix), bits(transform3.offset),
            bits(transform4.matrix), bits(transform4.offset), bits(dielectric),
        ]
    }
}

/// Shares immutable parameter buffers by value. A material edit selects a new
/// buffer, preserving constants already referenced by in-flight draws.
public struct PBR3DUniforms: Resource {
    public static let binding = 15
    private struct Key: Hashable {
        let words: [SIMD4<UInt32>]

        init(_ value: PBR3DUniform) {
            words = value.bitPatterns
        }
    }
    private struct Entry { let buffer: any UniformBuffer; var frame: Int }
    private struct MaterialEntry {
        // Retain identity owners until the frame ends, preventing identifier reuse.
        let owner: Material
        let revision: UInt64?
        let buffer: any UniformBuffer
    }
    private var entries: [Key: Entry] = [:]
    private var materialBuffers: [ObjectIdentifier: MaterialEntry] = [:]
    private var frame = 0

    public init() {}

    public mutating func beginFrame() {
        for (key, entry) in entries where entry.frame != frame { entries.removeValue(forKey: key) }
        frame &+= 1
        materialBuffers.removeAll(keepingCapacity: true)
    }

    public mutating func write(material: Material, descriptor: VertexDescriptor, device: RenderDevice) {
        let identity = ObjectIdentifier(material)
        let pbr = material as? PBRMaterial
        let revision = pbr?.uniformRevision
        if let entry = materialBuffers[identity], entry.revision == revision { return }
        let uniform = PBR3DUniform(material: pbr, descriptor: descriptor)
        let key = Key(uniform)
        if var entry = entries[key] {
            if entry.frame != frame {
                entry.frame = frame
                entries[key] = entry
            }
            materialBuffers[identity] = MaterialEntry(owner: material, revision: revision, buffer: entry.buffer)
        } else {
            let buffer = device.createUniformBuffer(PBR3DUniform.self, binding: Self.binding)
            buffer.setData(uniform)
            entries[key] = Entry(buffer: buffer, frame: frame)
            materialBuffers[identity] = MaterialEntry(owner: material, revision: revision, buffer: buffer)
        }
    }

    public func buffer(for material: Material) -> (any UniformBuffer)? {
        materialBuffers[ObjectIdentifier(material)]?.buffer
    }
}
