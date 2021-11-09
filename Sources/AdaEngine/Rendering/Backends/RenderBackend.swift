//
//  RenderBackend.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

import Math

struct Uniforms {
    var modelMatrix: Transform3D = .identity
    var viewMatrix: Transform3D = .identity
    var projectionMatrix: Transform3D = .identity
}

struct Vertex {
    var position: Vector3
    var normal: Vector3
    var uv: Vector2
    var color: Color
}

protocol RenderBackend: AnyObject {
    
    var viewportSize: Vector2i { get }
    
    func createWindow(for view: RenderView, size: Vector2i) throws
    func resizeWindow(newSize: Vector2i) throws

    func beginFrame() throws
    func endFrame() throws
    
    func sync()
    
    // MARK: - Drawable
    
    func renderDrawableList(_ list: DrawableList, camera: CameraData)
    
    func makePipelineDescriptor(for material: Material, vertexDescriptor: MeshVertexDescriptor?) throws -> Any
    
    // MARK: - Buffers
    
    func makeBuffer(length: Int, options: UInt) -> RenderBuffer
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: UInt) -> RenderBuffer
}
