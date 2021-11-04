//
//  Mesh.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import MetalKit
import ModelIO

protocol Resource {
    
}

public struct Mesh: Resource {
    
    public var verticies: [Vector3] {
        didSet {
            self.vertexBuffer.updateBuffer(self.verticies, length: MemoryLayout<Vector3>.stride * self.verticies.count)
        }
    }
    
    public var indicies: [Int] {
        didSet {
            self.indiciesBuffer.updateBuffer(self.indicies, length: MemoryLayout<Int>.stride * self.indicies.count)
        }
    }
    
    var submeshes: [Mesh] = []
    
    /// Include submeshes vertex count
    public var vertexCount: Int {
        return self.submeshes
            .map(\.vertexCount)
            .reduce(self.verticies.count, +)
    }
    
    var vertexDescriptor: MeshVertexDescriptor
    
    internal var vertexBuffer: Buffer
    internal var indiciesBuffer: Buffer
    
    public init(
        verticies: [Vector3] = [],
        indicies: [Int] = [],
        descriptor: MeshVertexDescriptor = .defaultVertexDescriptor,
        submeshes: [Mesh] = []
    ) {
        self.vertexDescriptor = descriptor
        
        self.vertexBuffer = Buffer(from: verticies)
        self.indiciesBuffer = Buffer(from: indicies)
        
        self.verticies = verticies
        self.indicies = indicies
        
        self.submeshes = submeshes
    }
    
}

public extension Mesh {
    static func loadMesh(from url: URL) -> Mesh {
        let asset = MDLAsset(url: url)
        fatalError()

    }
}
