import AdaECS
@_spi(Internal) import AdaRender
import Math

/// Frame-buffered weights of the active morph targets, one uniform buffer per entity and mesh part.
///
/// A part's vertex count and layout differ from its siblings', so each part gets its own buffer even though the weights belong to
/// the entity. The buffer holds the current and the previous frame's active targets, so the motion pass can move a vertex from
/// where the previous weights put it.
///
/// Layout, as 18 `vec4`: `[0]` current target count, previous target count, vertices per target, attributes per vertex; `[1]`
/// attribute flags; `[2..<10]` current (target index, weight); `[10..<18]` previous (target index, weight).
public struct Morph3DUniforms: Resource {
    /// The vertex-stage slot of the weights buffer.
    public static let binding = 21
    /// The vertex-stage slot of the delta texture.
    public static let textureBinding = 40
    static let vectorCount = 18

    /// Identifies one part of an entity's mesh.
    public struct PartKey: Hashable, Sendable {
        public let entity: Entity.ID
        public let model: Int
        public let part: Int
    }

    private struct Entry {
        var buffers: [(any UniformBuffer)?]
        var frame: Int
        var previous: [(index: Int, weight: Float)]
    }

    private var entries: [PartKey: Entry] = [:]
    private var frame = 0
    private var currentIndex = 0
    private let bufferCount: Int
    private var upload = [Vector4](repeating: .zero, count: vectorCount)

    public init() {
        bufferCount = max(1, unsafe RenderEngine.configurations.maxFramesInFlight)
    }

    public mutating func beginFrame() {
        for (key, entry) in entries where entry.frame != frame {
            entries.removeValue(forKey: key)
        }
        frame &+= 1
        currentIndex = (currentIndex + 1) % bufferCount
    }

    /// Test hooks for the buffer layout, which need no ``MorphTargetSet`` and so no GPU.
    static let vectorCountForTests = vectorCount

    static func packForTests(
        current: [(index: Int, weight: Float)],
        previous: [(index: Int, weight: Float)],
        vertexCount: Int,
        attributes: Int,
        flags: Float,
        into vectors: inout [Vector4]
    ) {
        pack(current: current, previous: previous, header: (vertexCount, attributes, flags), into: &vectors)
    }

    /// The vector array a part's buffer holds for these weights; the previous list is the last frame's when there is one.
    static func pack(
        current: [(index: Int, weight: Float)],
        previous: [(index: Int, weight: Float)],
        set: MorphTargetSet,
        into vectors: inout [Vector4]
    ) {
        pack(current: current, previous: previous, header: (set.vertexCount, set.attributesPerVertex, set.attributeFlags), into: &vectors)
    }

    private static func pack(
        current: [(index: Int, weight: Float)],
        previous: [(index: Int, weight: Float)],
        header: (vertexCount: Int, attributes: Int, flags: Float),
        into vectors: inout [Vector4]
    ) {
        for index in vectors.indices { vectors[index] = .zero }
        vectors[0] = Vector4(Float(current.count), Float(previous.count), Float(header.vertexCount), Float(header.attributes))
        vectors[1] = Vector4(header.flags, 0, 0, 0)
        for (slot, active) in current.prefix(MorphTargetSet.maximumActiveTargets).enumerated() {
            vectors[2 + slot] = Vector4(Float(active.index), active.weight, 0, 0)
        }
        for (slot, active) in previous.prefix(MorphTargetSet.maximumActiveTargets).enumerated() {
            vectors[10 + slot] = Vector4(Float(active.index), active.weight, 0, 0)
        }
    }

    /// The buffers written for the current frame, for tests.
    func debugBuffers() -> [any UniformBuffer] {
        entries.values.compactMap { $0.frame == frame ? $0.buffers[currentIndex] : nil }
    }

    /// Writes the buffers of every morphed part of `mesh` for an entity and returns them by part.
    public mutating func write(
        weights: [Float],
        mesh: Mesh,
        for entity: Entity.ID,
        device: RenderDevice
    ) -> [PartKey: any UniformBuffer] {
        let current = MorphTargetSet.activeTargets(weights: weights)
        var result: [PartKey: any UniformBuffer] = [:]
        for (modelIndex, model) in mesh.models.enumerated() {
            for (partIndex, part) in model.parts.enumerated() {
                guard let set = part.morphTargets else { continue }
                let key = PartKey(entity: entity, model: modelIndex, part: partIndex)
                var entry = entries[key] ?? Entry(buffers: Array(repeating: nil, count: bufferCount), frame: frame, previous: current)
                if entry.buffers[currentIndex] == nil {
                    entry.buffers[currentIndex] = device.createUniformBuffer(Vector4.self, count: Self.vectorCount, binding: Self.binding)
                }
                Self.pack(current: current, previous: entry.previous, set: set, into: &upload)
                entry.buffers[currentIndex]?.setElements(&upload)
                entry.previous = current
                entry.frame = frame
                entries[key] = entry
                if let buffer = entry.buffers[currentIndex] {
                    result[key] = buffer
                }
            }
        }
        return result
    }
}
