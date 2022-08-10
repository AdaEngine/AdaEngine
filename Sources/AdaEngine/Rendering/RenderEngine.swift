//
//  RenderEngine.swift
//  
//
//  Created by v.prusakov on 10/25/21.
//

import OrderedCollections

public class RenderEngine: RenderBackend {
    
    public static let shared: RenderEngine = {
        let renderBackend: RenderBackend
        
        renderBackend = MetalRenderBackend(appName: "Ada Engine")
        
        return RenderEngine(renderBackend: renderBackend)
    }()
    
    private let renderBackend: RenderBackend
    
    private init(renderBackend: RenderBackend) {
        self.renderBackend = renderBackend
    }
    
    func createWindow(_ windowId: Window.ID, for view: RenderView, size: Size) throws {
        try self.renderBackend.createWindow(windowId, for: view, size: size)
    }
    
    func resizeWindow(_ windowId: Window.ID, newSize: Size) throws {
        try self.renderBackend.resizeWindow(windowId, newSize: newSize)
    }
    
    func destroyWindow(_ windowId: Window.ID) throws {
        try self.renderBackend.destroyWindow(windowId)
    }
    
    func beginFrame() throws {
        try self.renderBackend.beginFrame()
    }
    
    func endFrame() throws {
        try self.renderBackend.endFrame()
    }
    
    func setClearColor(_ color: Color, forWindow windowId: Window.ID) {
        self.renderBackend.setClearColor(color, forWindow: windowId)
    }
    
    func makeBuffer(length: Int, options: ResourceOptions) -> RID {
        return self.renderBackend.makeBuffer(length: length, options: options)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> RID {
        return self.renderBackend.makeBuffer(bytes: bytes, length: length, options: options)
    }
    
    func getBuffer(for rid: RID) -> RenderBuffer {
        return self.renderBackend.getBuffer(for: rid)
    }
    
    func makeIndexArray(indexBuffer: RID, indexOffset: Int, indexCount: Int) -> RID {
        return self.renderBackend.makeIndexArray(indexBuffer: indexBuffer, indexOffset: indexOffset, indexCount: indexCount)
    }
    
    func makeVertexArray(vertexBuffers: [RID], vertexCount: Int) -> RID {
        return self.renderBackend.makeVertexArray(vertexBuffers: vertexBuffers, vertexCount: vertexCount)
    }
    
    func makeIndexBuffer(offset: Int, index: Int, format: IndexBufferFormat, bytes: UnsafeRawPointer?, length: Int) -> RID {
        return self.renderBackend.makeIndexBuffer(offset: offset, index: index, format: format, bytes: bytes, length: length)
    }
    
    func makeVertexBuffer(offset: Int, index: Int, bytes: UnsafeRawPointer?, length: Int) -> RID {
        return self.renderBackend.makeVertexBuffer(offset: offset, index: index, bytes: bytes, length: length)
    }
    
    func setVertexBufferData(_ vertexBuffer: RID, bytes: UnsafeRawPointer, length: Int) {
        self.renderBackend.setVertexBufferData(vertexBuffer, bytes: bytes, length: length)
    }
    
    func setIndexBufferData(_ indexBuffer: RID, bytes: UnsafeRawPointer, length: Int) {
        self.renderBackend.setIndexBufferData(indexBuffer, bytes: bytes, length: length)
    }
    
    func makeShader(from descriptor: ShaderDescriptor) -> RID {
        return self.renderBackend.makeShader(from: descriptor)
    }
    
    func makePipelineState(for shader: RID) -> RID {
        return self.renderBackend.makePipelineState(for: shader)
    }
    
    func makeUniform<T>(_ uniformType: T.Type, count: Int, offset: Int, options: ResourceOptions) -> RID {
        self.renderBackend.makeUniform(uniformType, count: count, offset: offset, options: options)
    }
    
    func updateUniform<T>(_ rid: RID, value: T, count: Int) {
        self.renderBackend.updateUniform(rid, value: value, count: count)
    }
    
    func removeUniform(_ rid: RID) {
        self.renderBackend.removeUniform(rid)
    }
    
    func makeTexture(from image: Image, type: Texture.TextureType, usage: Texture.Usage) -> RID {
        self.renderBackend.makeTexture(from: image, type: type, usage: usage)
    }
    
    func removeTexture(by rid: RID) {
        self.renderBackend.removeTexture(by: rid)
    }
    
    func getImage(for texture2D: RID) -> Image? {
        self.renderBackend.getImage(for: texture2D)
    }
    
    func beginDraw(for window: Window.ID) -> RID {
        self.renderBackend.beginDraw(for: window)
    }
    
    func bindVertexArray(_ draw: RID, vertexArray: RID) {
        self.renderBackend.bindVertexArray(draw, vertexArray: vertexArray)
    }
    
    func bindIndexArray(_ draw: RID, indexArray: RID) {
        self.renderBackend.bindIndexArray(draw, indexArray: indexArray)
    }
    
    func bindUniformSet(_ draw: RID, uniformSet: RID, at index: Int) {
        self.renderBackend.bindUniformSet(draw, uniformSet: uniformSet, at: index)
    }
    
    func bindTexture(_ draw: RID, texture: RID, at index: Int) {
        self.renderBackend.bindTexture(draw, texture: texture, at: index)
    }
    
    func bindTriangleFillMode(_ draw: RID, mode: TriangleFillMode) {
        self.renderBackend.bindTriangleFillMode(draw, mode: mode)
    }
    
    func bindRenderState(_ draw: RID, renderPassId: RID) {
        self.renderBackend.bindRenderState(draw, renderPassId: renderPassId)
    }
    
    func bindDebugName(name: String, forDraw draw: RID) {
        self.renderBackend.bindDebugName(name: name, forDraw: draw)
    }
    
    func setLineWidth(_ lineWidth: Float, forDraw draw: RID) {
        self.renderBackend.setLineWidth(lineWidth, forDraw: draw)
    }
    
    func draw(_ list: RID, indexCount: Int, instancesCount: Int) {
        self.renderBackend.draw(list, indexCount: indexCount, instancesCount: instancesCount)
    }
    
    func drawEnd(_ drawId: RID) {
        self.renderBackend.drawEnd(drawId)
    }
}
