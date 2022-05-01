//
//  Mesh.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import MetalKit
import ModelIO

public class Mesh: Resource {
    
    public struct Surface: Identifiable {
        
        public let id: Int
        
        var name: String = ""
        
        var primitiveType: Mesh.PrimitiveType
        
        var isUInt32: Bool
        
        var indexBuffer: RenderBuffer
        var indexCount: Int
        
        public var materialIndex: Int
    }
    
    struct Model {
        var name: String
        
        var vertexBuffer: RenderBuffer
        var vertexCount: Int
        
        var surfaces: [Surface] = []
    }
    
    internal var models: [Mesh.Model] = []
   
    internal var vertexDescriptor: MeshVertexDescriptor
    
    internal init(vertexDescriptor: MeshVertexDescriptor = .defaultVertexDescriptor) {
        self.vertexDescriptor = vertexDescriptor
    }
    
}

public extension Mesh {
    static func loadMesh(from url: URL, vertexDescriptor: MeshVertexDescriptor? = nil) -> Mesh {
        let asset = MDLAsset(
            url: url,
            vertexDescriptor: nil,
            bufferAllocator: nil
        )
        
        let mdlMesh = asset.childObjects(of: MDLMesh.self).first as! MDLMesh
        
        return Mesh(mdlMesh: mdlMesh)
    }
}

#if canImport(ModelIO)
extension Mesh {
    convenience init(mdlMesh: MDLMesh) {
        self.init(vertexDescriptor: MeshVertexDescriptor(mdlVertexDescriptor: mdlMesh.vertexDescriptor))
        
        var model = Mesh.Model(
            name: mdlMesh.name,
            vertexBuffer: RenderEngine.shared.makeBuffer(
                bytes: mdlMesh.vertexBuffers[0].map().bytes,
                length: mdlMesh.vertexBuffers[0].length,
                options: []
            ),
            vertexCount: mdlMesh.vertexCount,
            surfaces: []
        )
        
        for (index, submesh) in (mdlMesh.submeshes as! [MDLSubmesh]).enumerated() {
            let surface = Mesh.Surface(
                id: index,
                name: submesh.name,
                primitiveType: .triangles,
                isUInt32: submesh.indexType == .uInt32,
                indexBuffer: RenderEngine.shared.makeBuffer(
                    bytes: submesh.indexBuffer.map().bytes,
                    length: submesh.indexBuffer.length,
                    options: []
                ),
                indexCount: submesh.indexCount,
                materialIndex: 0
            )
            
            model.surfaces.append(surface)
        }
        
        self.models = [model]
    }
}
#endif

extension Mesh {
    static func generateBox(extent: Vector3, segments: Vector3) -> Mesh {
        let mdlMesh = MDLMesh(
            boxWithExtent: [extent.x, extent.y, extent.z],
            segments: [UInt32(segments.x), UInt32(segments.y), UInt32(segments.z)],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: nil)
        
        return Mesh(mdlMesh: mdlMesh)
    }
    
    static func generateSphere(extent: Vector3, segments: Vector2) -> Mesh {
        let mdlMesh = MDLMesh(
            sphereWithExtent: extent,
            segments: [UInt32(segments.x), UInt32(segments.y)],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: nil
        )
        
        return Mesh(mdlMesh: mdlMesh)
    }
}
