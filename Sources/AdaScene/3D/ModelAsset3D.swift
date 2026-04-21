//
//  ModelAsset3D.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaAssets
@_spi(Internal) import AdaRender
import Math
import AdaECS
import AdaTransform
import Foundation

/// An asset that represents a 3D model.
public final class ModelAsset3D: Asset, @unchecked Sendable {
    
    public struct Node: Sendable {
        public let name: String?
        public let transform: Transform3D
        public let meshIndex: Int?
        public let children: [Int]
        
        public init(name: String?, transform: Transform3D, meshIndex: Int?, children: [Int]) {
            self.name = name
            self.transform = transform
            self.meshIndex = meshIndex
            self.children = children
        }
    }
    
    public let nodes: [Node]
    public let meshes: [Mesh]
    public let materials: [Material]
    public let scenes: [[Int]]
    public let defaultScene: Int?
    
    public var assetMetaInfo: AssetMetaInfo?
    
    public init(nodes: [Node], meshes: [Mesh], materials: [Material], scenes: [[Int]], defaultScene: Int?) {
        self.nodes = nodes
        self.meshes = meshes
        self.materials = materials
        self.scenes = scenes
        self.defaultScene = defaultScene
    }
    
    public init(from assetDecoder: any AssetDecoder) async throws {
        let loader = GLTFLoaderResolver.shared.getLoader()
        let result = try await loader.load(url: assetDecoder.assetMeta.filePath)
        
        let device = unsafe RenderEngine.shared.renderDevice
        
        // 1. Convert Materials
        var materials: [Material] = []
        for gltfMaterial in result.materials {
            let material = PBRMaterial()
            material.baseColorFactor = gltfMaterial.baseColorFactor
            material.metallicFactor = gltfMaterial.metallicFactor
            material.roughnessFactor = gltfMaterial.roughnessFactor
            
            if let textureIndex = gltfMaterial.baseColorTextureIndex {
                let gltfTexture = result.textures[textureIndex]
                let gltfImage = result.images[gltfTexture.source]
                
                if let data = gltfImage.data {
                    if let image = try? Image.decode(from: data) {
                        material.baseColorTexture = Texture2D(image: image)
                    }
                }
            }
            
            if let textureIndex = gltfMaterial.metallicRoughnessTextureIndex {
                let gltfTexture = result.textures[textureIndex]
                let gltfImage = result.images[gltfTexture.source]
                
                if let data = gltfImage.data {
                    if let image = try? Image.decode(from: data) {
                        material.metallicRoughnessTexture = Texture2D(image: image)
                    }
                }
            }
            
            if let textureIndex = gltfMaterial.normalTextureIndex {
                let gltfTexture = result.textures[textureIndex]
                let gltfImage = result.images[gltfTexture.source]
                
                if let data = gltfImage.data {
                    if let image = try? Image.decode(from: data) {
                        material.normalTexture = Texture2D(image: image)
                    }
                }
            }
            
            materials.append(material)
        }
        
        // 2. Convert Meshes
        var meshes: [Mesh] = []
        for gltfMesh in result.meshes {
            var parts: [Mesh.Part] = []
            
            for (index, primitive) in gltfMesh.primitives.enumerated() {
                var descriptor = MeshDescriptor(name: "Primitive \(index)")
                
                if let posData = primitive.attributes[.position] {
                    descriptor.positions = MeshBuffer(posData.withUnsafeBytes { Array($0.bindMemory(to: Vector3.self)) })
                }
                
                if let normalData = primitive.attributes[.normal] {
                    descriptor.normals = MeshBuffer(normalData.withUnsafeBytes { Array($0.bindMemory(to: Vector3.self)) })
                }
                
                if let uvData = primitive.attributes[.texCoord(0)] {
                    descriptor.textureCoordinates = MeshBuffer(uvData.withUnsafeBytes { Array($0.bindMemory(to: Vector2.self)) })
                }
                
                if let indices = primitive.indices {
                    descriptor.indicies = indices.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }
                }
                
                let part = Mesh.Part(
                    id: index,
                    materialIndex: primitive.materialIndex ?? 0,
                    primitiveTopology: .triangleList,
                    isUInt32: true,
                    meshDescriptor: descriptor,
                    vertexDescriptor: descriptor.getMeshVertexBufferDescriptor(),
                    indexBuffer: descriptor.getIndexBuffer(renderDevice: device),
                    indexCount: descriptor.indicies.count,
                    vertexBuffer: descriptor.getVertexBuffer(renderDevice: device)
                )
                parts.append(part)
            }
            
            meshes.append(Mesh(models: [Mesh.Model(name: gltfMesh.name ?? "", parts: parts)]))
        }
        
        self.nodes = result.nodes.map { Node(name: $0.name, transform: $0.transform, meshIndex: $0.meshIndex, children: $0.children) }
        self.meshes = meshes
        self.materials = materials
        self.scenes = result.scenes
        self.defaultScene = result.defaultScene
    }
    
    @discardableResult
    public func instantiate(in world: World) -> Entity {
        let rootEntity = world.spawn(self.assetName)
        
        let sceneIndex = self.defaultScene ?? 0
        if self.scenes.indices.contains(sceneIndex) {
            let nodeIndices = self.scenes[sceneIndex]
            for nodeIndex in nodeIndices {
                self.instantiateNode(nodeIndex, parent: rootEntity, in: world)
            }
        }
        
        return rootEntity
    }
    
    private func instantiateNode(_ nodeIndex: Int, parent: Entity, in world: World) {
        let node = self.nodes[nodeIndex]
        let entity = world.spawn(node.name ?? "Node \(nodeIndex)")
        entity.components[Transform.self] = Transform(matrix: node.transform)
        
        if let meshIndex = node.meshIndex {
            let mesh = self.meshes[meshIndex]
            entity.components[Mesh3DComponent.self] = Mesh3DComponent(mesh: mesh, materials: self.materials)
        }
        
        parent.addChild(entity)
        
        for childIndex in node.children {
            self.instantiateNode(childIndex, parent: entity, in: world)
        }
    }
    
    public func encodeContents(with assetEncoder: any AssetEncoder) async throws {
        fatalError("Not implemented")
    }
    
    public static func extensions() -> [String] {
        return ["gltf", "glb"]
    }
}
