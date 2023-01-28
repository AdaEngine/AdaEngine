//
//  RenderEngine.swift
//  
//
//  Created by v.prusakov on 10/25/21.
//

import OrderedCollections

// TODO: (Vlad) we should compile all shader on setup
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
    
    // MARK: - RenderBackend
    
    public var currentFrameIndex: Int {
        return self.renderBackend.currentFrameIndex
    }
    
    public func createWindow(_ windowId: Window.ID, for view: RenderView, size: Size) throws {
        try self.renderBackend.createWindow(windowId, for: view, size: size)
    }
    
    public func resizeWindow(_ windowId: Window.ID, newSize: Size) throws {
        try self.renderBackend.resizeWindow(windowId, newSize: newSize)
    }
    
    public func destroyWindow(_ windowId: Window.ID) throws {
        try self.renderBackend.destroyWindow(windowId)
    }
    
    func beginFrame() throws {
        try self.renderBackend.beginFrame()
    }
    
    func endFrame() throws {
        try self.renderBackend.endFrame()
    }
    
    func makeBuffer(length: Int, options: ResourceOptions) -> Buffer {
        return self.renderBackend.makeBuffer(length: length, options: options)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        return self.renderBackend.makeBuffer(bytes: bytes, length: length, options: options)
    }
    
    func makeIndexArray(indexBuffer: IndexBuffer, indexOffset: Int, indexCount: Int) -> RID {
        return self.renderBackend.makeIndexArray(indexBuffer: indexBuffer, indexOffset: indexOffset, indexCount: indexCount)
    }
    
    func makeVertexArray(vertexBuffers: [RID], vertexCount: Int) -> RID {
        return self.renderBackend.makeVertexArray(vertexBuffers: vertexBuffers, vertexCount: vertexCount)
    }
    
    func makeIndexBuffer(index: Int, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        return self.renderBackend.makeIndexBuffer(index: index, format: format, bytes: bytes, length: length)
    }
    
    func makeVertexBuffer(offset: Int, index: Int, bytes: UnsafeRawPointer?, length: Int) -> RID {
        return self.renderBackend.makeVertexBuffer(offset: offset, index: index, bytes: bytes, length: length)
    }
    
    func setVertexBufferData(_ vertexBuffer: RID, bytes: UnsafeRawPointer, length: Int) {
        self.renderBackend.setVertexBufferData(vertexBuffer, bytes: bytes, length: length)
    }
    
    func makeRenderPass(from descriptor: RenderPassDescriptor) -> RenderPass {
        return self.renderBackend.makeRenderPass(from: descriptor)
    }
    
    func makeSampler(from descriptor: SamplerDescriptor) -> Sampler {
        return self.renderBackend.makeSampler(from: descriptor)
    }
    
    func makeRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        return self.renderBackend.makeRenderPipeline(from: descriptor)
    }
    
    func makeShader(from descriptor: ShaderDescriptor) -> Shader {
        return self.renderBackend.makeShader(from: descriptor)
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
    
    func makeTexture(from descriptor: TextureDescriptor) -> RID {
        self.renderBackend.makeTexture(from: descriptor)
    }
    
    func removeTexture(by rid: RID) {
        self.renderBackend.removeTexture(by: rid)
    }
    
    func getImage(for texture2D: RID) -> Image? {
        self.renderBackend.getImage(for: texture2D)
    }
    
    // MARK: - Drawing
    
    func beginDraw(for window: Window.ID) -> DrawList {
        self.renderBackend.beginDraw(for: window)
    }
    
    func beginDraw(for window: Window.ID, renderPass: RenderPass) -> DrawList {
        self.renderBackend.beginDraw(for: window, renderPass: renderPass)
    }
    
    func draw(_ list: DrawList, indexCount: Int, instancesCount: Int) {
        self.renderBackend.draw(list, indexCount: indexCount, instancesCount: instancesCount)
    }
    
    func endDrawList(_ drawList: DrawList) {
        self.renderBackend.endDrawList(drawList)
    }
}
