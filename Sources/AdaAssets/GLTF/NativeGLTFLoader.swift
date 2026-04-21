//
//  NativeGLTFLoader.swift
//  AdaEngine
//
//  Created by v.prusakov on 05/30/24.
//

import Foundation
import Math

public struct NativeGLTFLoader: GLTFLoader {
    
    public init() {}
    
    public func load(url: URL) async throws -> GLTFImportResult {
        let data = try Data(contentsOf: url)
        
        let gltf: GLTF
        let binaryBuffer: Data?
        
        if data.prefix(4) == Data("glTF".utf8) {
            let (parsedGltf, parsedBinaryBuffer) = try parseGLB(data)
            gltf = parsedGltf
            binaryBuffer = parsedBinaryBuffer
        } else {
            gltf = try JSONDecoder().decode(GLTF.self, from: data)
            binaryBuffer = nil
        }
        
        let buffers = try await loadBuffers(gltf.buffers ?? [], baseURL: url.deletingLastPathComponent(), binaryBuffer: binaryBuffer)
        
        return try convertToImportResult(gltf, buffers: buffers)
    }
    
    private func parseGLB(_ data: Data) throws -> (GLTF, Data?) {
        let magic = data.subdata(in: 0..<4)
        let version = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }
        let length = data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self) }
        
        if magic != Data("glTF".utf8) || version != 2 {
            throw GLTFError.invalidGLB
        }
        
        var offset = 12
        var gltf: GLTF?
        var binaryBuffer: Data?
        
        while offset < data.count {
            let chunkLength = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
            let chunkType = data.subdata(in: offset+4..<offset+8).withUnsafeBytes { $0.load(as: UInt32.self) }
            let chunkData = data.subdata(in: offset+8..<offset+8+Int(chunkLength))
            
            if chunkType == 0x4E4F534A { // JSON
                gltf = try JSONDecoder().decode(GLTF.self, from: chunkData)
            } else if chunkType == 0x004E4942 { // BIN
                binaryBuffer = chunkData
            }
            
            offset += 8 + Int(chunkLength)
        }
        
        guard let resultGltf = gltf else {
            throw GLTFError.missingJSONChunk
        }
        
        return (resultGltf, binaryBuffer)
    }
    
    private func loadBuffers(_ gltfBuffers: [GLTF.Buffer], baseURL: URL, binaryBuffer: Data?) async throws -> [Data] {
        var buffers = [Data]()
        
        for (index, buffer) in gltfBuffers.enumerated() {
            if index == 0, let binaryBuffer = binaryBuffer {
                buffers.append(binaryBuffer)
                continue
            }
            
            guard let uri = buffer.uri else {
                if index == 0, binaryBuffer == nil {
                     throw GLTFError.missingBufferURI
                }
                continue
            }
            
            if uri.starts(with: "data:") {
                if let data = try? Data(contentsOf: URL(string: uri)!) {
                    buffers.append(data)
                } else {
                    throw GLTFError.invalidDataURI
                }
            } else {
                let bufferURL = baseURL.appendingPathComponent(uri)
                let data = try Data(contentsOf: bufferURL)
                buffers.append(data)
            }
        }
        
        return buffers
    }
    
    private func convertToImportResult(_ gltf: GLTF, buffers: [Data]) throws -> GLTFImportResult {
        let images = (gltf.images ?? []).map { image -> GLTFImportResult.Image in
            if let uri = image.uri {
                if uri.starts(with: "data:") {
                     return GLTFImportResult.Image(uri: nil, data: try? Data(contentsOf: URL(string: uri)!), mimeType: image.mimeType)
                }
                return GLTFImportResult.Image(uri: URL(string: uri), data: nil, mimeType: image.mimeType)
            } else if let bufferViewIndex = image.bufferView {
                let bufferView = gltf.bufferViews![bufferViewIndex]
                let buffer = buffers[bufferView.buffer]
                let data = buffer.subdata(in: bufferView.byteOffset..<(bufferView.byteOffset + bufferView.byteLength))
                return GLTFImportResult.Image(uri: nil, data: data, mimeType: image.mimeType)
            }
            return GLTFImportResult.Image(uri: nil, data: nil, mimeType: image.mimeType)
        }
        
        let textures = (gltf.textures ?? []).map { texture in
            GLTFImportResult.Texture(source: texture.source ?? 0, sampler: texture.sampler)
        }
        
        let materials = (gltf.materials ?? []).map { material -> GLTFImportResult.Material in
            let pbr = material.pbrMetallicRoughness
            let baseColorFactor = pbr?.baseColorFactor ?? [1, 1, 1, 1]
            let baseColor = Vector4(x: baseColorFactor[0], y: baseColorFactor[1], z: baseColorFactor[2], w: baseColorFactor[3])
            
            return GLTFImportResult.Material(
                name: material.name,
                baseColorFactor: baseColor,
                baseColorTextureIndex: pbr?.baseColorTexture?.index,
                metallicFactor: pbr?.metallicFactor ?? 1.0,
                roughnessFactor: pbr?.roughnessFactor ?? 1.0,
                metallicRoughnessTextureIndex: pbr?.metallicRoughnessTexture?.index,
                normalTextureIndex: material.normalTexture?.index
            )
        }
        
        let meshes = try (gltf.meshes ?? []).map { mesh -> GLTFImportResult.Mesh in
            let primitives = try mesh.primitives.map { primitive -> GLTFImportResult.Primitive in
                var attributes = [GLTFImportResult.Attribute: Data]()
                
                for (key, accessorIndex) in primitive.attributes {
                    let attribute = try mapAttribute(key)
                    attributes[attribute] = try getAccessorData(accessorIndex, gltf: gltf, buffers: buffers)
                }
                
                let indicesData: Data?
                if let indicesIndex = primitive.indices {
                    indicesData = try getAccessorData(indicesIndex, gltf: gltf, buffers: buffers)
                } else {
                    indicesData = nil
                }
                
                return GLTFImportResult.Primitive(
                    attributes: attributes,
                    indices: indicesData,
                    materialIndex: primitive.material,
                    mode: GLTFImportResult.PrimitiveMode(rawValue: primitive.mode ?? 4) ?? .triangles
                )
            }
            
            return GLTFImportResult.Mesh(name: mesh.name, primitives: primitives)
        }
        
        let nodes = (gltf.nodes ?? []).map { node -> GLTFImportResult.Node in
            let transform: Transform3D
            
            if let matrix = node.matrix {
                // glTF uses column-major matrices
                transform = Transform3D(
                    Vector4(x: matrix[0], y: matrix[1], z: matrix[2], w: matrix[3]),
                    Vector4(x: matrix[4], y: matrix[5], z: matrix[6], w: matrix[7]),
                    Vector4(x: matrix[8], y: matrix[9], z: matrix[10], w: matrix[11]),
                    Vector4(x: matrix[12], y: matrix[13], z: matrix[14], w: matrix[15])
                )
            } else {
                let translation = node.translation ?? [0, 0, 0]
                let rotation = node.rotation ?? [0, 0, 0, 1]
                let scale = node.scale ?? [1, 1, 1]
                
                let t = Transform3D(translation: Vector3(x: translation[0], y: translation[1], z: translation[2]))
                let r = Transform3D(quat: Quat(x: rotation[0], y: rotation[1], z: rotation[2], w: rotation[3]))
                let s = Transform3D(scale: Vector3(x: scale[0], y: scale[1], z: scale[2]))
                
                transform = t * r * s
            }
            
            return GLTFImportResult.Node(
                name: node.name,
                transform: transform,
                children: node.children ?? [],
                meshIndex: node.mesh
            )
        }
        
        let scenes = (gltf.scenes ?? []).map { $0.nodes ?? [] }
        
        return GLTFImportResult(
            nodes: nodes,
            meshes: meshes,
            materials: materials,
            textures: textures,
            images: images,
            scenes: scenes,
            defaultScene: gltf.scene
        )
    }
    
    private func mapAttribute(_ key: String) throws -> GLTFImportResult.Attribute {
        switch key {
        case "POSITION": return .position
        case "NORMAL": return .normal
        case "TANGENT": return .tangent
        case let str where str.starts(with: "TEXCOORD_"):
            let index = Int(str.dropFirst("TEXCOORD_".count)) ?? 0
            return .texCoord(index)
        case let str where str.starts(with: "COLOR_"):
            let index = Int(str.dropFirst("COLOR_".count)) ?? 0
            return .color(index)
        case let str where str.starts(with: "JOINTS_"):
            let index = Int(str.dropFirst("JOINTS_".count)) ?? 0
            return .joints(index)
        case let str where str.starts(with: "WEIGHTS_"):
            let index = Int(str.dropFirst("WEIGHTS_".count)) ?? 0
            return .weights(index)
        default:
            throw GLTFError.unknownAttribute(key)
        }
    }
    
    private func getAccessorData(_ accessorIndex: Int, gltf: GLTF, buffers: [Data]) throws -> Data {
        let accessor = gltf.accessors![accessorIndex]
        guard let bufferViewIndex = accessor.bufferView else {
             // Accessor with no buffer view should be initialized with zeros, but let's keep it simple for now
             return Data()
        }
        
        let bufferView = gltf.bufferViews![bufferViewIndex]
        let buffer = buffers[bufferView.buffer]
        
        let componentSize: Int
        switch accessor.componentType {
        case 5120, 5121: componentSize = 1 // BYTE, UNSIGNED_BYTE
        case 5122, 5123: componentSize = 2 // SHORT, UNSIGNED_SHORT
        case 5125, 5126: componentSize = 4 // UNSIGNED_INT, FLOAT
        default: throw GLTFError.invalidComponentType(accessor.componentType)
        }
        
        let numberOfComponents: Int
        switch accessor.type {
        case "SCALAR": numberOfComponents = 1
        case "VEC2": numberOfComponents = 2
        case "VEC3": numberOfComponents = 3
        case "VEC4": numberOfComponents = 4
        case "MAT2": numberOfComponents = 4
        case "MAT3": numberOfComponents = 9
        case "MAT4": numberOfComponents = 16
        default: throw GLTFError.invalidAccessorType(accessor.type)
        }
        
        let stride = bufferView.byteStride ?? (componentSize * numberOfComponents)
        let totalSize = accessor.count * componentSize * numberOfComponents
        let offset = bufferView.byteOffset + accessor.byteOffset
        
        if bufferView.byteStride == nil || bufferView.byteStride == (componentSize * numberOfComponents) {
            return buffer.subdata(in: offset..<(offset + totalSize))
        } else {
            // Interleaved data, we need to extract it
            var data = Data(capacity: totalSize)
            for i in 0..<accessor.count {
                let start = offset + (i * stride)
                data.append(buffer.subdata(in: start..<(start + componentSize * numberOfComponents)))
            }
            return data
        }
    }
    
    // MARK: - Internal GLTF Schema
    
    private enum GLTFError: Error {
        case invalidGLB
        case missingJSONChunk
        case missingBufferURI
        case invalidDataURI
        case unknownAttribute(String)
        case invalidComponentType(Int)
        case invalidAccessorType(String)
    }
    
    private struct GLTF: Codable {
        struct Buffer: Codable {
            let uri: String?
            let byteLength: Int
        }
        
        struct BufferView: Codable {
            let buffer: Int
            let byteOffset: Int
            let byteLength: Int
            let byteStride: Int?
            let target: Int?
        }
        
        struct Accessor: Codable {
            let bufferView: Int?
            let byteOffset: Int
            let componentType: Int
            let count: Int
            let type: String
            let min: [Float]?
            let max: [Float]?
        }
        
        struct Mesh: Codable {
            struct Primitive: Codable {
                let attributes: [String: Int]
                let indices: Int?
                let material: Int?
                let mode: Int?
            }
            
            let name: String?
            let primitives: [Primitive]
        }
        
        struct Material: Codable {
            struct PBR: Codable {
                struct TextureInfo: Codable {
                    let index: Int
                    let texCoord: Int?
                }
                
                let baseColorFactor: [Float]?
                let baseColorTexture: TextureInfo?
                let metallicFactor: Float?
                let roughnessFactor: Float?
                let metallicRoughnessTexture: TextureInfo?
            }
            
            struct NormalTextureInfo: Codable {
                let index: Int
                let texCoord: Int?
                let scale: Float?
            }
            
            let name: String?
            let pbrMetallicRoughness: PBR?
            let normalTexture: NormalTextureInfo?
        }
        
        struct Texture: Codable {
            let sampler: Int?
            let source: Int?
        }
        
        struct Image: Codable {
            let uri: String?
            let mimeType: String?
            let bufferView: Int?
        }
        
        struct Node: Codable {
            let name: String?
            let children: [Int]?
            let matrix: [Float]?
            let translation: [Float]?
            let rotation: [Float]?
            let scale: [Float]?
            let mesh: Int?
            let camera: Int?
        }
        
        struct Scene: Codable {
            let nodes: [Int]?
            let name: String?
        }
        
        let asset: Asset
        let scene: Int?
        let scenes: [Scene]?
        let nodes: [Node]?
        let meshes: [Mesh]?
        let accessors: [Accessor]?
        let bufferViews: [BufferView]?
        let buffers: [Buffer]?
        let materials: [Material]?
        let textures: [Texture]?
        let images: [Image]?
        
        struct Asset: Codable {
            let version: String
        }
    }
}
