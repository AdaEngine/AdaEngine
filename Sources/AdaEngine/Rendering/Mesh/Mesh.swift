//
//  Mesh.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import Math

// TODO: Add Resource implementation
public class Mesh: Resource {
    
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
    
    // MARK: - Resource
    
    public var resourcePath: String = ""
    public var resourceName: String = ""
    public static var resourceType: ResourceType = .mesh
    
    public required init(asset decoder: AssetDecoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalErrorMethodNotImplemented()
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

public extension Mesh {
    /// Compute the Axis-Aligned Bounding Box of the mesh vertices in model space
    func computeAABB() -> AABB? {
        
        let floatMin = -Float.greatestFiniteMagnitude
        
        var minimum: Vector3 = Vector3(.greatestFiniteMagnitude)
        var maximum: Vector3 = Vector3(floatMin)
        
        for model in self.models {
            for part in model.parts {
                for position in part.meshDescriptor.positions {
                    minimum = min(minimum, position)
                    maximum = max(maximum, position)
                }
            }
        }
        
        if minimum.x != .greatestFiniteMagnitude && minimum.y != .greatestFiniteMagnitude
            && minimum.z != .greatestFiniteMagnitude && maximum.x != floatMin
            && maximum.y != floatMin && maximum.z != floatMin {
            return AABB(min: minimum, max: maximum)
        }
        
        return nil
    }
}
