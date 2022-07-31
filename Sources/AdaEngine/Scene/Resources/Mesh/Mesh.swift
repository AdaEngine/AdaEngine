//
//  Mesh.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import MetalKit
import ModelIO

public class Mesh {
    
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
    let source: Source
    
    internal init(vertexDescriptor: MeshVertexDescriptor = .defaultVertexDescriptor, source: Source) {
        self.vertexDescriptor = vertexDescriptor
        self.source = source
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let source = try container.decode(Source.self, forKey: .source)
        
        let mesh: Mesh
        
        switch source {
        case let .box(extent, segments):
            mesh = Mesh.generateBox(extent: extent, segments: segments)
        case let .sphere(extent, segments):
            mesh = Mesh.generateSphere(extent: extent, segments: segments)
        case .url(let url):
            mesh = Mesh.loadMesh(from: url, vertexDescriptor: nil)
        }
        
        self.source = source
        self.vertexDescriptor = mesh.vertexDescriptor
        self.models = mesh.models
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.source, forKey: .source)
    }
    
    enum Source: Codable {
        case url(URL)
        case box(extent: Vector3, segments: Vector3)
        case sphere(extent: Vector3, segments: Vector2)
    }
    
    enum CodingKeys: String, CodingKey {
        case source
        case vertexDescriptor
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
        
        return Mesh(mdlMesh: mdlMesh, source: .url(url))
    }
}

#if canImport(ModelIO)
extension Mesh {
    convenience init(mdlMesh: MDLMesh, source: Source) {
        self.init(
            vertexDescriptor: MeshVertexDescriptor(mdlVertexDescriptor: mdlMesh.vertexDescriptor),
            source: source
        )
        
        let rid = RenderEngine.shared.makeBuffer(
            bytes: mdlMesh.vertexBuffers[0].map().bytes,
            length: mdlMesh.vertexBuffers[0].length,
            options: []
        )
        
        var model = Mesh.Model(
            name: mdlMesh.name,
            vertexBuffer: RenderEngine.shared.getBuffer(for: rid),
            vertexCount: mdlMesh.vertexCount,
            surfaces: []
        )
        
        for (index, submesh) in (mdlMesh.submeshes as! [MDLSubmesh]).enumerated() {
            
            let rid = RenderEngine.shared.makeBuffer(
                bytes: submesh.indexBuffer.map().bytes,
                length: submesh.indexBuffer.length,
                options: []
            )
            
            let surface = Mesh.Surface(
                id: index,
                name: submesh.name,
                primitiveType: .triangles,
                isUInt32: submesh.indexType == .uInt32,
                indexBuffer: RenderEngine.shared.getBuffer(for: rid),
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
        
        return Mesh(
            mdlMesh: mdlMesh,
            source: .box(extent: extent, segments: segments)
        )
    }
    
    static func generateSphere(extent: Vector3, segments: Vector2) -> Mesh {
        let mdlMesh = MDLMesh(
            sphereWithExtent: [extent.x, extent.y, extent.z],
            segments: [UInt32(segments.x), UInt32(segments.y)],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: nil
        )
        
        return Mesh(
            mdlMesh: mdlMesh,
            source: .sphere(extent: extent, segments: segments)
        )
    }
}
