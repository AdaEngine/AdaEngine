//
//  CanvasMaterial.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/2/23.
//

import AdaAssets
import AdaUtils
import Foundation

/// This material can be render Meshes in 2D world.
public protocol CanvasMaterial: ReflectedMaterial { }

public extension CanvasMaterial {
    
    static func vertexShader() throws -> AssetHandle<ShaderSource> {
        return try AssetsManager.loadSync(
            ShaderSource.self, 
            at: "Shaders/mesh2d/mesh2d.glsl#vert",
            from: Bundle.module
        )
    }
    
    static func fragmentShader() throws -> AssetHandle<ShaderSource> {
        return try AssetsManager.loadSync(
            ShaderSource.self, 
            at: "Shaders/mesh2d/mesh2d.glsl#frag",
            from: Bundle.module
        )
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
        var descriptor = RenderPipelineDescriptor(vertex: vertex)
        descriptor.debugName = "Canvas Mesh Material \(String(describing: self))"
        descriptor.fragment = fragment
        descriptor.vertexDescriptor = vertexDescriptor
        descriptor.backfaceCulling = true
        descriptor.colorAttachments = [
            RenderPipelineColorAttachmentDescriptor(
                format: .bgra8,
                isBlendingEnabled: true
            )
        ]
        
        return descriptor
    }
}

/// Unlit color material. Material will fill all mesh with color.
public struct ColorCanvasMaterial: CanvasMaterial {
    
    @Uniform(binding: 0, propertyName: "u_Color")
    public var color: Color
    
    public init(color: Color) {
        self.color = color
    }
    
    public static func fragmentShader() throws -> AssetHandle<ShaderSource> {
        return try AssetsManager.loadSync(
            ShaderSource.self, 
            at: "Shaders/Materials/color_canvas_material.glsl",
            from: Bundle.module
        )
    }
}

/// Circle material will render circle on mesh.
struct CircleCanvasMaterial: CanvasMaterial {
    
    @Uniform(binding: 0, propertyName: "u_Thickness")
    var thickness: Float
    
    @Uniform(binding: 0, propertyName: "u_Fade")
    var fade: Float
    
    @Uniform(binding: 0, propertyName: "u_Color")
    var color: Color
    
    init(thickness: Float, fade: Float, color: Color) {
        self.thickness = thickness
        self.fade = fade
        self.color = color
    }
    
    public static func fragmentShader() throws -> AssetHandle<ShaderSource> {
        return try AssetsManager.loadSync(
            ShaderSource.self, 
            at: "Shaders/Materials/circle_canvas_material.glsl", 
            from: Bundle.module
        )
    }
}
