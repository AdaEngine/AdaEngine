//
//  Mesh.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import Math

public class Mesh {
    
    public struct Part: Identifiable {
        public let id: Int
        
        public var materialIndex: Int
        public var name: String = ""
        
        let primitiveTopology: Mesh.PrimitiveTopology
        
        let isUInt32: Bool
        
        let meshDescriptor: MeshDescriptor
        
        internal var vertexDescriptor: VertexDescriptor
        
        var indexBuffer: IndexBuffer
        var indexCount: Int
        var vertexBuffer: VertexBuffer
    }
    
    public struct Model {
        let name: String
        
        var parts: [Part] = []
    }
    
    internal var models: [Mesh.Model] = []
    
    internal init(models: [Model]) {
        self.models = models
    }
    
    enum CodingKeys: String, CodingKey {
        case vertexDescriptor
    }
    
}

public extension Mesh {
    static func generate(from meshDescriptors: [MeshDescriptor]) -> Mesh {
        var parts = [Part]()
        
        for (index, meshDescriptor) in meshDescriptors.enumerated() {
            let part = Part(
                id: index,
                materialIndex: 0,
                primitiveTopology: meshDescriptor.primitiveTopology,
                isUInt32: true,
                meshDescriptor: meshDescriptor,
                vertexDescriptor: meshDescriptor.getMeshVertexBufferDescriptor(),
                indexBuffer: meshDescriptor.getIndexBuffer(),
                indexCount: meshDescriptor.indicies.count,
                vertexBuffer: meshDescriptor.getVertexBuffer()
            )
            
            parts.append(part)
        }
  
        let model = Model(name: "", parts: parts)
        return Mesh(models: [model])
    }
    
    static func generate(from shape: Shape) -> Mesh {
        return self.generate(from: [shape.meshDescriptor()])
    }
}

#if METAL

//public extension Mesh {
//    static func loadMesh(from url: URL, vertexDescriptor: MeshVertexDescriptor? = nil) -> Mesh {
//        #if METAL
//        let asset = MDLAsset(
//            url: url,
//            vertexDescriptor: nil,
//            bufferAllocator: nil
//        )
//
//        let mdlMesh = asset.childObjects(of: MDLMesh.self).first as! MDLMesh
//
//        return Mesh(mdlMesh: mdlMesh)
//        #else
//        fatalError()
//        #endif
//    }
//}

//extension Mesh {
//    convenience init(mdlMesh: MDLMesh) {
//        let buffer = RenderEngine.shared.makeBuffer(
//            bytes: mdlMesh.vertexBuffers[0].map().bytes,
//            length: mdlMesh.vertexBuffers[0].length,
//            options: []
//        )
//
//        var model = Mesh.Model(
//            name: mdlMesh.name,
//            vertexBuffer: buffer,
//            vertexCount: mdlMesh.vertexCount,
//            parts: []
//        )
//
//        for (index, submesh) in (mdlMesh.submeshes as! [MDLSubmesh]).enumerated() {
//
//            let buffer = RenderEngine.shared.makeBuffer(
//                bytes: submesh.indexBuffer.map().bytes,
//                length: submesh.indexBuffer.length,
//                options: [.storageShared]
//            )
//
//            let surface = Mesh.Part(
//                id: index,
//                name: submesh.name,
//                primitiveTopology: .triangleList,
//                meshDescriptor: <#MeshDescriptor#>,
//                isUInt32: submesh.indexType == .uInt32,
//                indexBuffer: buffer,
//                indexCount: submesh.indexCount,
//                materialIndex: 0
//            )
//
//            model.surfaces.append(surface)
//        }
//
//        self.init(
//            models: [model],
//            vertexDescriptor: MeshVertexDescriptor(mdlVertexDescriptor: mdlMesh.vertexDescriptor)
//        )
//    }
//}

//public extension Mesh {
//    static func generateBox(extent: Vector3, segments: Vector3) -> Mesh {
//        let mdlMesh = MDLMesh(
//            boxWithExtent: [extent.x, extent.y, extent.z],
//            segments: [UInt32(segments.x), UInt32(segments.y), UInt32(segments.z)],
//            inwardNormals: false,
//            geometryType: .triangles,
//            allocator: nil)
//
//        return Mesh(
//            mdlMesh: mdlMesh,
//            source: .box(extent: extent, segments: segments)
//        )
//    }
//
//    static func generateSphere(extent: Vector3, segments: Vector2) -> Mesh {
//        let mdlMesh = MDLMesh(
//            sphereWithExtent: [extent.x, extent.y, extent.z],
//            segments: [UInt32(segments.x), UInt32(segments.y)],
//            inwardNormals: false,
//            geometryType: .triangles,
//            allocator: nil
//        )
//
//        return Mesh(
//            mdlMesh: mdlMesh,
//            source: .sphere(extent: extent, segments: segments)
//        )
//    }
//}

#endif

public protocol Shape {
    func meshDescriptor() -> MeshDescriptor
}

public struct Quad: Shape {
    
    public let size: Vector2
    
    public init(size: Vector2 = .one) {
        self.size = size
    }
    
    public func meshDescriptor() -> MeshDescriptor {
        let extentX = size.x / 2
        let extentY = size.y / 2
        
        var mesh = MeshDescriptor(name: "Quad")
        mesh.primitiveTopology = .triangleList
        mesh.indicies = [0, 1, 2, 2, 3, 0]
        mesh.positions = [
            [-extentX, -extentY,  0.0],
            [ extentX, -extentY,  0.0],
            [ extentX,  extentY,  0.0],
            [-extentX,  extentY,  0.0]
        ]
        mesh.normals = [
            [0, 0, 1],
            [0, 0, 1],
            [0, 0, 1],
            [0, 0, 1]
        ]
        mesh.textureCoordinates = [
            [0, 1], [1, 1], [1, 0], [0, 0]
        ]
        
        return mesh
    }
}
