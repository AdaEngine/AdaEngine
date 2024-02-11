//
//  VulkanRenderBackend.swift
//  
//
//  Created by v.prusakov on 8/20/23.
//

#if VULKAN

import Foundation
import Vulkan
import CVulkan
import Math

final class VulkanRenderBackend: RenderBackend {
    
    private let context: Context
    
    init(appName: String) {
        self.context = Context(appName: appName)
    }
    
    var currentFrameIndex: Int = 0
    
    func createWindow(_ windowId: Window.ID, for view: RenderView, size: Size) throws {
        try self.context.createRenderWindow(with: windowId, view: view, size: size)
    }
    
    func resizeWindow(_ windowId: Window.ID, newSize: Size) throws {
        self.context.updateSizeForRenderWindow(windowId, size: newSize)
    }
    
    func destroyWindow(_ windowId: Window.ID) throws {
        try self.context.destroyWindow(at: windowId)
    }
    
    func beginFrame() throws {
        
    }
    
    func endFrame() throws {
        
    }
    
    func makeBuffer(length: Int, options: ResourceOptions) -> Buffer {
        fatalError("Kek")
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        fatalError("Kek")
    }
    
    func makeIndexBuffer(index: Int, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        fatalError("Kek")
    }
    
    func makeVertexBuffer(length: Int, binding: Int) -> VertexBuffer {
        fatalError("Kek")
    }
    
    func compileShader(from shader: Shader) throws -> CompiledShader {
        fatalError("Kek")
    }
    
    func makeFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
        fatalError("Kek")
    }
    
    func makeRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        fatalError("Kek")
    }
    
    func makeSampler(from descriptor: SamplerDescriptor) -> Sampler {
        fatalError("Kek")
    }
    
    func makeUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        fatalError("Kek")
    }
    
    func makeUniformBufferSet() -> UniformBufferSet {
        fatalError("Kek")
    }
    
    func makeTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        fatalError("Kek")
    }
    
    func getImage(for texture2D: RID) -> Image? {
        fatalError("Kek")
    }
    
    func beginDraw(for window: Window.ID, clearColor: Color) -> DrawList {
        fatalError("Kek")
    }
    
    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) -> DrawList {
        fatalError("Kek")
    }
    
    func draw(_ list: DrawList, indexCount: Int, instancesCount: Int) {
        
    }
    
    func endDrawList(_ drawList: DrawList) {
        
    }
    
}

extension Version {
    var toVulkanVersion: UInt32 {
        return vkMakeApiVersion(UInt32(self.major), UInt32(self.minor), UInt32(self.patch))
    }
}

#endif
