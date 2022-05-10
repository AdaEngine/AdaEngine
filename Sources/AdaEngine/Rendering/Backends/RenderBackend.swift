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

protocol RenderBackend: AnyObject {
    
    var viewportSize: Vector2i { get }
    
    func createWindow(for view: RenderView, size: Vector2i) throws
    func resizeWindow(newSize: Vector2i) throws

    func beginFrame() throws
    func endFrame() throws
    
    func sync()
    
    func setClearColor(_ color: Color)
    
    // MARK: - Drawable
    
    func renderDrawableList(_ list: DrawableList, camera: CameraData)
    
    func makePipelineDescriptor(for material: Material, vertexDescriptor: MeshVertexDescriptor?) -> RID
    
    // MARK: - Buffers
    
    func makeBuffer(length: Int, options: ResourceOptions) -> RID
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> RID
    
    func getBuffer(for rid: RID) -> RenderBuffer
    
    func makeIndexBuffer(offset: Int, index: Int, bytes: UnsafeRawPointer?, length: Int) -> RID
    
    func makeVertexBuffer(offset: Int, index: Int, bytes: UnsafeRawPointer?, length: Int) -> RID
    
    func setVertexBufferData(_ vertexBuffer: RID, bytes: UnsafeRawPointer, length: Int)
    
    func setIndexBufferData(_ indexBuffer: RID, bytes: UnsafeRawPointer, length: Int)
    
    // MARK: - Shaders
    
    func makeShader(_ shaderName: String, vertexFuncName: String, fragmentFuncName: String) -> RID
    
    func bindAttributes(attributes: VertexDesciptorAttributesArray, forShader rid: RID)
    
    func bindLayouts(layouts: VertexDesciptorLayoutsArray, forShader rid: RID)
    
    func makePipelineState(for shader: RID) -> RID
    
    // MARK: - Uniforms
    
    func makeUniform<T>(_ uniformType: T.Type, count: Int, index: Int, offset: Int, options: ResourceOptions) -> RID
    
    func updateUniform<T>(_ rid: RID, value: T, count: Int)
    
    func removeUniform(_ rid: RID)
    
    // MARK: - Draw
    
    func beginDrawList() -> RID
    
    func bindVertexBuffer(_ drawRid: RID, vertexBuffer: RID)
    
    func bindIndexBuffer(_ drawRid: RID, indexBuffer: RID)
    
    func bindUniformSet(_ drawRid: RID, uniformSet: RID)
    
    func bindRenderState(_ drawRid: RID, renderPassId: RID)
    
    func bindDebugName(name: String, forDraw drawId: RID)
    
    func draw(_ list: RID, indexCount: Int, instancesCount: Int)
    
    func drawEnd(_ drawId: RID)
}
