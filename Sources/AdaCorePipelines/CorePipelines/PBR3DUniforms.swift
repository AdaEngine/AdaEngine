import AdaECS
@_spi(Internal) import AdaRender
import Math

/// Per-draw material parameters; vertex instance data retains color and metal/rough factors.
public struct PBR3DUniform: Sendable, Equatable {
    public let emissiveFactor: Vector4
    public let properties: Vector4
    public let flags: Vector4
    public let coordinates: Vector4
    public let emission: Vector4
    /// Parallax: height scale, UV set, maximum ray-march layers and fade distance.
    public let parallax: Vector4

    public init(material: PBRMaterial?, descriptor _: VertexDescriptor) {
        func coordinate(_ slot: Int) -> Int {
            guard let material, material.textureCoordinates.indices.contains(slot) else {
                return 0
            }
            return material.textureCoordinates[slot]
        }
        emissiveFactor = Vector4(material?.emissiveFactor ?? .one, 0)
        properties = Vector4(material?.normalScale ?? 1, material?.occlusionStrength ?? 1, material?.alphaCutoff ?? 0.5, Float(material?.alphaMode.rawValue ?? 0))
        let heightScale = material?.heightTexture != nil ? max(finiteRenderValue(material?.heightScale ?? 0, fallback: 0, range: 0...1000), 0) : 0
        flags = Vector4(material?.doubleSided ?? true ? 1 : 0, material?.occlusionTexture != nil ? 1 : 0, heightScale > 0 ? 1 : 0, 0)
        coordinates = Vector4(Float(coordinate(0)), Float(coordinate(1)), Float(coordinate(2)), Float(coordinate(3)))
        emission = Vector4(Float(coordinate(4)), material?.baseColorFactor.w ?? 1, 1, 0)
        parallax = Vector4(
            heightScale,
            Float(min(max(material?.heightTextureCoordinate ?? 0, 0), 1)),
            Float(min(max(material?.heightMaxLayers ?? 32, 4), 64)),
            finiteRenderValue(material?.heightFadeDistance ?? 30, fallback: 30, range: 0.1...100000)
        )
    }
}

/// Shares immutable parameter buffers by value. A material edit selects a new
/// buffer, preserving constants already referenced by in-flight draws.
public struct PBR3DUniforms: Resource {
    public static let binding = 15
    private struct Key: Hashable {
        let emissive: SIMD4<UInt32>
        let properties: SIMD4<UInt32>
        let flags: SIMD4<UInt32>
        let coordinates: SIMD4<UInt32>
        let emission: SIMD4<UInt32>
        let parallax: SIMD4<UInt32>

        init(_ value: PBR3DUniform) {
            func bits(_ vector: Vector4) -> SIMD4<UInt32> {
                SIMD4(vector.x.bitPattern, vector.y.bitPattern, vector.z.bitPattern, vector.w.bitPattern)
            }
            emissive = bits(value.emissiveFactor)
            properties = bits(value.properties)
            flags = bits(value.flags)
            coordinates = bits(value.coordinates)
            emission = bits(value.emission)
            parallax = bits(value.parallax)
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
