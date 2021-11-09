//
//  Mesh.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import MetalKit
import ModelIO

public protocol Resource {
    
}

public struct Mesh: Resource {
    
    public var verticies: [Vector3] {
        didSet {
            self.vertexBuffer.updateBuffer(self.verticies, length: MemoryLayout<Vector3>.stride * self.verticies.count)
        }
    }
    
    public var indicies: [UInt32] {
        didSet {
            self.indiciesBuffer.updateBuffer(self.indicies, length: MemoryLayout<Int32>.stride * self.indicies.count)
        }
    }
    
    var submeshes: [Mesh] = []
    
    /// Include submeshes vertex count
    public var vertexCount: Int {
        return self.submeshes
            .map(\.vertexCount)
            .reduce(self.verticies.count, +)
    }
    
    var vertexDescriptor: MeshVertexDescriptor = .defaultVertexDescriptor
    
    internal var vertexBuffer: Buffer
    internal var indiciesBuffer: Buffer
    
    public init(
        verticies: [Vector3] = [],
        indicies: [UInt32] = [],
        submeshes: [Mesh] = []
    ) {
        self.vertexBuffer = Buffer(byteCount: MemoryLayout<Vertex>.stride)
        self.indiciesBuffer = Buffer(from: indicies)
        
        self.verticies = verticies
        self.indicies = indicies
        
        self.submeshes = submeshes
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
        
        fatalError()
    }
}
