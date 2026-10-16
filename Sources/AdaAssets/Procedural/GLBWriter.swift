//
//  GLBWriter.swift
//  AdaEngine
//

import Foundation

public struct ProceduralMaterial: Sendable, Equatable {
    public var name: String
    public var baseColor: SIMD4<Float>
    public var metallic: Float
    public var roughness: Float
    public var emissive: SIMD3<Float>

    public init(name: String, baseColor: SIMD4<Float> = [0.8, 0.8, 0.8, 1], metallic: Float = 0, roughness: Float = 0.6, emissive: SIMD3<Float> = .zero) {
        self.name = name
        self.baseColor = baseColor
        self.metallic = metallic
        self.roughness = roughness
        self.emissive = emissive
    }
}

public struct ProceduralNode: Sendable, Equatable {
    public var name: String
    public var mesh: ProceduralMeshData?
    /// Index into ``ProceduralModel/materials``.
    public var material = 0
    public var translation = SIMD3<Float>.zero
    /// Quaternion `(x, y, z, w)`.
    public var rotation = SIMD4<Float>(0, 0, 0, 1)
    public var scale = SIMD3<Float>.one
    /// Index of the parent node, which must come earlier in ``ProceduralModel/nodes``.
    public var parent: Int?

    public init(name: String, mesh: ProceduralMeshData? = nil) {
        self.name = name
        self.mesh = mesh
    }
}

public struct ProceduralModel: Sendable, Equatable {
    public var materials: [ProceduralMaterial]
    public var nodes: [ProceduralNode]

    public init(materials: [ProceduralMaterial], nodes: [ProceduralNode]) {
        self.materials = materials
        self.nodes = nodes
    }
}

public enum GLBWritingError: Error, Equatable, Sendable {
    case noGeometry
    case invalidMaterial(node: Int)
    case invalidParent(node: Int)
    case invalidMesh(node: Int)
}

/// Encodes a ``ProceduralModel`` as a binary glTF 2.0 file that ``NativeGLTFLoader`` imports.
public struct GLBWriter: Sendable {
    public init() {}

    public func encode(_ model: ProceduralModel) throws -> Data {
        guard model.nodes.contains(where: { $0.mesh?.isEmpty == false }) else { throw GLBWritingError.noGeometry }

        var binary = Data()
        var bufferViews: [[String: Any]] = []
        var accessors: [[String: Any]] = []

        func addAccessor(_ values: [Float], components: Int, type: String, target: Int, bounds: Bool = false) -> Int {
            var data = Data(capacity: values.count * 4)
            for value in values { data.append(contentsOf: withUnsafeBytes(of: value.bitPattern.littleEndian) { Array($0) }) }
            return append(data, count: values.count / components, componentType: 5126, type: type, target: target, bounds: bounds ? values : nil, components: components)
        }
        func append(_ data: Data, count: Int, componentType: Int, type: String, target: Int, bounds: [Float]? = nil, components: Int = 1) -> Int {
            bufferViews.append(["buffer": 0, "byteOffset": binary.count, "byteLength": data.count, "target": target])
            binary.append(data)
            var accessor: [String: Any] = ["bufferView": bufferViews.count - 1, "componentType": componentType, "count": count, "type": type]
            if let bounds {
                var low = Array(bounds[0..<components]), high = low
                for start in stride(from: components, to: bounds.count, by: components) {
                    for axis in 0..<components {
                        low[axis] = min(low[axis], bounds[start + axis])
                        high[axis] = max(high[axis], bounds[start + axis])
                    }
                }
                accessor["min"] = doubles(low)
                accessor["max"] = doubles(high)
            }
            accessors.append(accessor)
            return accessors.count - 1
        }

        var nodes: [[String: Any]] = []
        var meshes: [[String: Any]] = []
        var children: [Int: [Int]] = [:]
        var roots: [Int] = []
        for (index, node) in model.nodes.enumerated() {
            var json: [String: Any] = ["name": node.name]
            if let mesh = node.mesh {
                guard mesh.positions.count == mesh.normals.count, mesh.positions.count == mesh.uvs.count, !mesh.isEmpty,
                    mesh.indices.allSatisfy({ Int($0) < mesh.positions.count })
                else { throw GLBWritingError.invalidMesh(node: index) }
                guard model.materials.indices.contains(node.material) else { throw GLBWritingError.invalidMaterial(node: index) }
                let position = addAccessor(mesh.positions.flatMap { [$0.x, $0.y, $0.z] }, components: 3, type: "VEC3", target: 34962, bounds: true)
                let normal = addAccessor(mesh.normals.flatMap { [$0.x, $0.y, $0.z] }, components: 3, type: "VEC3", target: 34962)
                let uv = addAccessor(mesh.uvs.flatMap { [$0.x, $0.y] }, components: 2, type: "VEC2", target: 34962)
                var indices = Data(capacity: mesh.indices.count * 4)
                for value in mesh.indices { indices.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) }) }
                let indexAccessor = append(indices, count: mesh.indices.count, componentType: 5125, type: "SCALAR", target: 34963)
                meshes.append([
                    "name": node.name,
                    "primitives": [
                        [
                            "attributes": ["POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv],
                            "indices": indexAccessor,
                            "material": node.material,
                        ] as [String: Any]
                    ],
                ])
                json["mesh"] = meshes.count - 1
            }
            if node.translation != .zero { json["translation"] = doubles(node.translation) }
            if node.rotation != SIMD4(0, 0, 0, 1) { json["rotation"] = doubles(node.rotation) }
            if node.scale != .one { json["scale"] = doubles(node.scale) }
            nodes.append(json)
            if let parent = node.parent {
                guard parent >= 0, parent < index else { throw GLBWritingError.invalidParent(node: index) }
                children[parent, default: []].append(index)
            } else {
                roots.append(index)
            }
        }
        for (parent, list) in children { nodes[parent]["children"] = list }

        let materials = model.materials.map { material -> [String: Any] in
            var json: [String: Any] = [
                "name": material.name,
                "pbrMetallicRoughness": [
                    "baseColorFactor": doubles(material.baseColor),
                    "metallicFactor": Double(material.metallic),
                    "roughnessFactor": Double(material.roughness),
                ] as [String: Any],
            ]
            if material.emissive != .zero { json["emissiveFactor"] = doubles(material.emissive) }
            return json
        }
        let document: [String: Any] = [
            "asset": ["version": "2.0", "generator": "AdaEngine procedural model"],
            "scene": 0,
            "scenes": [["nodes": roots]],
            "nodes": nodes,
            "meshes": meshes,
            "materials": materials,
            "accessors": accessors,
            "bufferViews": bufferViews,
            "buffers": [["byteLength": binary.count]],
        ]
        var json = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
        while json.count % 4 != 0 { json.append(0x20) }
        while binary.count % 4 != 0 { binary.append(0) }

        var file = Data()
        func appendUInt32(_ value: Int) { file.append(contentsOf: withUnsafeBytes(of: UInt32(truncatingIfNeeded: value).littleEndian) { Array($0) }) }
        appendUInt32(0x4654_6C67)
        appendUInt32(2)
        appendUInt32(12 + 8 + json.count + 8 + binary.count)
        appendUInt32(json.count)
        appendUInt32(0x4E4F_534A)
        file.append(json)
        appendUInt32(binary.count)
        appendUInt32(0x004E_4942)
        file.append(binary)
        return file
    }
}
