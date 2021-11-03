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
    
    public var verticies: [Vector3]
    public var indicies: [Int]
    
    var submeshes: [Mesh] = []
    
    /// Include submeshes vertex count
    public var vertexCount: Int {
        return self.submeshes
            .map(\.vertexCount)
            .reduce(self.verticies.count, +)
    }
    
    var vertexDescriptor: MeshVertexDescriptor
    
    public init(
        verticies: [Vector3] = [],
        indicies: [Int] = [],
        descriptor: MeshVertexDescriptor = .defaultVertexDescriptor,
        submeshes: [Mesh] = []
    ) {
        self.verticies = verticies
        self.indicies = indicies
        self.vertexDescriptor = descriptor
    }
    
}

public extension Mesh {
    static func loadMesh(from url: URL) -> Mesh {
        let asset = MDLAsset(url: url)
        
        fatalError()
    }
}
