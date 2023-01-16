//
//  RenderBackend.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

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

public enum TriangleFillMode {
    case fill
    case lines
}

protocol RenderBackend: AnyObject {
    
    func createWindow(_ windowId: Window.ID, for view: RenderView, size: Size) throws
    func resizeWindow(_ windowId: Window.ID, newSize: Size) throws
    func destroyWindow(_ windowId: Window.ID) throws
    
//    func sync() throws
    
    /// Begin rendering a frame.
    func beginFrame() throws
    
    /// Release any data associated with the current frame.
    func endFrame() throws
    
    func setClearColor(_ color: Color, forWindow windowId: Window.ID)
    
    // MARK: - Buffers
    
    func makeBuffer(length: Int, options: ResourceOptions) -> RID
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> RID
    
    func getBuffer(for rid: RID) -> RenderBuffer
    
    func makeIndexArray(indexBuffer: RID, indexOffset: Int, indexCount: Int) -> RID
    
    func makeVertexArray(vertexBuffers: [RID], vertexCount: Int) -> RID
    
    func makeIndexBuffer(offset: Int, index: Int, format: IndexBufferFormat, bytes: UnsafeRawPointer?, length: Int) -> RID
    
    func makeVertexBuffer(offset: Int, index: Int, bytes: UnsafeRawPointer?, length: Int) -> RID
    
    func setVertexBufferData(_ vertexBuffer: RID, bytes: UnsafeRawPointer, length: Int)
    
    func setIndexBufferData(_ indexBuffer: RID, bytes: UnsafeRawPointer, length: Int)
    
    // MARK: - Shaders
    
    /// Create shader from descriptor.
    func makeShader(from descriptor: ShaderDescriptor) -> Shader
    
    func makeRenderPass(from descriptor: RenderPassDescriptor) -> RenderPass
    
    /// Create pipeline state from shader.
    func makeRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline
    
    // MARK: - Uniforms
    
    func makeUniform<T>(_ uniformType: T.Type, count: Int, offset: Int, options: ResourceOptions) -> RID
    
    func updateUniform<T>(_ rid: RID, value: T, count: Int)
    
    func removeUniform(_ rid: RID)
    
    // MARK: - Texture
    
    func makeTexture(from image: Image, type: Texture.TextureType, usage: Texture.Usage) -> RID
    
    func removeTexture(by rid: RID)
    
    func getImage(for texture2D: RID) -> Image?
    
    // MARK: - Draw
    
    func beginDraw(for window: Window.ID) -> DrawList
    
    func beginDraw(for window: Window.ID, renderPass: RenderPass) -> DrawList
    
    func draw(_ list: DrawList, indexCount: Int, instancesCount: Int)
    
    func endDrawList(_ drawList: DrawList)
}
