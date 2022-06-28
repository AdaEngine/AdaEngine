//
//  ShaderDescriptor.swift
//  
//
//  Created by v.prusakov on 5/31/22.
//

/// The base struct describing shader.
public struct ShaderDescriptor {
    public let shaderName: String
    
    public let vertexFunction: String
    public let fragmentFunction: String
    
    public var vertexDescriptor: MeshVertexDescriptor

    public init(
        shaderName: String,
        vertexFunction: String,
        fragmentFunction: String
    ) {
        self.shaderName = shaderName
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        self.vertexDescriptor = MeshVertexDescriptor()
    }
    
}
