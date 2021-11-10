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
        
        var indexBuffer: RenderBuffer
        var indexCount: Int
        
        var materialIndex: Int
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
            vertexDescriptor: vertexDescriptor?.makeMDLVertexDescriptor(),
            bufferAllocator: nil
        )
        
        let mdlMesh = asset.childObjects(of: MDLMesh.self).first as! MDLMesh
        
        let mesh = Mesh(vertexDescriptor: MeshVertexDescriptor(mdlVertexDescriptor: mdlMesh.vertexDescriptor))
        
        var model = Mesh.Model(
            name: mdlMesh.name,
            vertexBuffer: RenderEngine.shared.makeBuffer(
                bytes: mdlMesh.vertexBuffers[0].map().bytes,
                length: mdlMesh.vertexBuffers[0].length,
                options: 0
            ),
            vertexCount: mdlMesh.vertexCount,
            surfaces: []
        )
        
        for (index, submesh) in (mdlMesh.submeshes as! [MDLSubmesh]).enumerated() {
            let surface = Mesh.Surface(
                id: index,
                name: submesh.name,
                primitiveType: .triangles,
                indexBuffer: RenderEngine.shared.makeBuffer(
                    bytes: submesh.indexBuffer.map().bytes,
                    length: submesh.indexBuffer.length,
                    options: 0
                ),
                indexCount: submesh.indexCount,
                materialIndex: 0
            )
            
            model.surfaces.append(surface)
        }
        
        
        mesh.models = [model]
        
        
        return mesh
    }
}
