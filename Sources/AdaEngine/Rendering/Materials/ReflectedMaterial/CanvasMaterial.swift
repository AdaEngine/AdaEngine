//
//  CanvasMaterial.swift
//  
//
//  Created by v.prusakov on 4/2/23.
//

/// This material can be render Meshes in 2D world.
public protocol CanvasMaterial: ReflectedMaterial { }

public extension CanvasMaterial {
    
    static func vertexShader() throws -> ShaderSource {
        return try ResourceManager.load("Shaders/Vulkan/mesh2d/mesh2d.glsl#vert", from: .engineBundle)
    }
    
    static func fragmentShader() throws -> ShaderSource {
        return try ResourceManager.load("Shaders/Vulkan/mesh2d/mesh2d.glsl#frag", from: .engineBundle)
    }
    
    static func configureShaderDefines(
        keys: Set<String>,
        vertexDescriptor: VertexDescriptor
    ) -> [ShaderDefine] {
        var defines = [ShaderDefine]()
        
        if vertexDescriptor.attributes.containsAttribute(by: MeshDescriptor.positions.id.name) {
            defines.append(.define("VERTEX_POSITIONS"))
        }
        
        if vertexDescriptor.attributes.containsAttribute(by: MeshDescriptor.colors.id.name) {
            defines.append(.define("VERTEX_COLORS"))
        }
        
        if vertexDescriptor.attributes.containsAttribute(by: MeshDescriptor.normals.id.name) {
            defines.append(.define("VERTEX_NORMALS"))
        }
        
        if vertexDescriptor.attributes.containsAttribute(by: MeshDescriptor.textureCoordinates.id.name) {
            defines.append(.define("VERTEX_UVS"))
        }
        
        return defines
    }
    
    static func configurePipeline(
        keys: Set<String>,
        vertex: Shader,
        fragment: Shader,
        vertexDescriptor: VertexDescriptor
    ) throws -> RenderPipelineDescriptor {
        var descriptor = RenderPipelineDescriptor()
        descriptor.debugName = "Canvas Mesh Material \(String(describing: self))"
        descriptor.vertex = vertex
        descriptor.fragment = fragment
        descriptor.vertexDescriptor = vertexDescriptor
        descriptor.backfaceCulling = true
        descriptor.colorAttachments = [
            ColorAttachmentDescriptor(
                format: .bgra8,
                isBlendingEnabled: true
            )
        ]
        
        return descriptor
    }
}

public struct ColorCanvasMaterial: CanvasMaterial {
    
    @Uniform(binding: 0, propertyName: "u_Color")
    public var color: Color
    
    public init(color: Color) {
        self.color = color
    }
    
    public static func fragmentShader() throws -> ShaderSource {
        return try ResourceManager.load("Shaders/Vulkan/mesh2d/color_canvas_material.glsl", from: .engineBundle)
    }
}
