//
//  Mesh.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import Math

// TODO: We should generate AABB for mesh

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
