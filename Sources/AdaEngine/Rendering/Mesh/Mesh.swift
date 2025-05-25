//
//  Mesh.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/1/21.
//

import Math

// TODO: Add Resource implementation

/// A high-level representation of a collection of vertices and edges that define a shape.
public class Mesh: Asset, @unchecked Sendable {
    
    /// A part of a model consisting of a single material.
    public struct Part: Identifiable, Sendable {
        
        /// The stable identity of the entity associated with this instance.
        public let id: Int
        
        /// Material index for the part.
        public var materialIndex: Int
        
        let primitiveTopology: Mesh.PrimitiveTopology
        
        let isUInt32: Bool
        
        /// Descriptors for the buffers.
        let meshDescriptor: MeshDescriptor
        
        internal var vertexDescriptor: VertexDescriptor
        
        /// Index buffer for triangles.
        public var indexBuffer: IndexBuffer
        var indexCount: Int
        var vertexBuffer: VertexBuffer
    }
    
    /// A model consists of a list of parts.
    public struct Model {
        let name: String
        
        /// Table of parts composing this mesh.
        public var parts: [Part] = []
    }
    
    internal var models: [Mesh.Model] = []
    
    internal init(models: [Model]) {
        self.models = models
        self.bounds = Self.computeAABB(models: models) ?? .empty
    }
    
    enum CodingKeys: String, CodingKey {
        case vertexDescriptor
    }
    
    /// A box that bounds the mesh.
    public private(set) var bounds: AABB
    
    // MARK: - Resource
    
    public var assetMetaInfo: AssetMetaInfo?
    
    public required init(asset decoder: AssetDecoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public required init(from decoder: any Decoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func encode(to encoder: any Encoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public static func extensions() -> [String] {
        ["mesh"]
    }
}

public extension Mesh {
    
    /// Create a mesh resource from a list of mesh descriptors.
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
    
    /// Create a mesh resource from a shape.
    static func generate(from shape: GeometryShape) -> Mesh {
        return self.generate(from: [shape.meshDescriptor()])
    }
}

fileprivate extension Mesh {
    /// Compute the Axis-Aligned Bounding Box of the mesh vertices in model space
    static func computeAABB(models: [Mesh.Model]) -> AABB? {
        
        let floatMin = -Float.greatestFiniteMagnitude
        
        var minimum: Vector3 = Vector3(.greatestFiniteMagnitude)
        var maximum: Vector3 = Vector3(floatMin)
        
        for model in models {
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
