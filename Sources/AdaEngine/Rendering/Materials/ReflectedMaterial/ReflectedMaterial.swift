//
//  ReflectedMaterial.swift
//  
//
//  Created by v.prusakov on 4/2/23.
//

public protocol ReflectedMaterial: ShaderBindable {
    
    static func vertexShader() throws -> ShaderSource
    
    static func fragmentShader() throws -> ShaderSource
    
    static func configureShaderDefines(
        keys: Set<String>,
        vertexDescriptor: VertexDescriptor
    ) -> [ShaderDefine]
    
    static func configurePipeline(
        keys: Set<String>,
        vertex: Shader,
        fragment: Shader,
        vertexDescriptor: VertexDescriptor
    ) throws -> RenderPipelineDescriptor
}
