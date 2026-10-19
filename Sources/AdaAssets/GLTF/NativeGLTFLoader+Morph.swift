import Foundation
import Math

extension NativeGLTFLoader {
    /// Reads the morph targets of one primitive. Each target lists the attributes it displaces (POSITION, NORMAL,
    /// TANGENT); every accessor must be a float-vector per vertex of the primitive. Other morphed attributes are
    /// ignored and reported by `warnings(for:)`.
    func importMorphTargets(
        _ primitive: GLTF.Mesh.Primitive,
        attributes: [GLTFImportResult.Attribute: GLTFImportResult.Accessor],
        gltf: GLTF,
        buffers: [Data],
        meshIndex: Int
    ) throws -> [GLTFImportResult.MorphTarget] {
        guard let targets = primitive.targets, !targets.isEmpty else {
            return []
        }
        guard let positions = attributes[.position] else {
            throw GLTFError.invalidMorphTargets(meshIndex)
        }
        func deltas(_ name: String, in target: [String: Int]) throws -> [Vector3] {
            guard let accessorIndex = target[name] else { return [] }
            let accessor = try checkedAccessor(accessorIndex, gltf: gltf)
            let decoded = try decodeAccessor(accessorIndex, gltf: gltf, buffers: buffers)
            guard accessor.type == "VEC3", decoded.componentCount == 3, decoded.values.count == positions.count * 3,
                decoded.values.allSatisfy({ $0.isFinite })
            else {
                throw GLTFError.invalidMorphTargets(meshIndex)
            }
            var vectors: [Vector3] = []
            vectors.reserveCapacity(positions.count)
            for offset in stride(from: 0, to: decoded.values.count, by: 3) {
                let x = Float(decoded.values[offset]), y = Float(decoded.values[offset + 1]), z = Float(decoded.values[offset + 2])
                vectors.append(Vector3(x, y, z))
            }
            return vectors
        }
        return try targets.map { target in
            GLTFImportResult.MorphTarget(
                positionDeltas: try deltas("POSITION", in: target),
                normalDeltas: try deltas("NORMAL", in: target),
                tangentDeltas: try deltas("TANGENT", in: target)
            )
        }
    }

    /// Checks that every primitive of a mesh has the same number of targets and that the default weights and names match.
    func importMorphMetadata(
        _ mesh: GLTF.Mesh,
        primitives: [GLTFImportResult.Primitive],
        meshIndex: Int
    ) throws -> (weights: [Float], names: [String]) {
        let count = primitives.first?.morphTargets.count ?? 0
        guard primitives.allSatisfy({ $0.morphTargets.count == count }) else {
            throw GLTFError.invalidMorphTargets(meshIndex)
        }
        guard count > 0 else {
            // Weights or names without targets mean nothing; an authored non-empty list is an error.
            if mesh.weights?.isEmpty == false { throw GLTFError.invalidMorphTargets(meshIndex) }
            return ([], [])
        }
        let weights = mesh.weights ?? [Float](repeating: 0, count: count)
        let names = mesh.extras?.targetNames ?? []
        guard weights.count == count, weights.allSatisfy(\.isFinite), names.isEmpty || names.count == count else {
            throw GLTFError.invalidMorphTargets(meshIndex)
        }
        return (weights, names)
    }

    /// The number of morph targets of the mesh a node instantiates.
    func morphTargetCount(ofNode node: GLTF.Node, in gltf: GLTF) -> Int {
        guard let meshIndex = node.mesh, let meshes = gltf.meshes, meshes.indices.contains(meshIndex) else {
            return 0
        }
        return meshes[meshIndex].primitives.first?.targets?.count ?? 0
    }
}
