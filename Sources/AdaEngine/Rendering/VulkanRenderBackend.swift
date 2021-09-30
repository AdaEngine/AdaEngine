//
//  VulkanRenderBackend.swift
//  
//
//  Created by v.prusakov on 9/9/21.
//

import CVulkan
import Vulkan
import Math
import Foundation

public protocol RenderBackend: AnyObject {
    func createWindow(for view: RenderView, size: Vector2i) throws
    func resizeWindow(newSize: Vector2i) throws
    func beginFrame() throws
    func endFrame() throws
}

public class VulkanRenderBackend: RenderBackend {
    
    private let context: VulkanRenderContext
    
    var shaders: [VulkanShader] = []
    
    public init(appName: String) throws {
        self.context = VulkanRenderContext()
        try self.context.initialize(with: appName)
    }
    
    public func resizeWindow(newSize: Vector2i) throws {
        self.context.framebufferSize = newSize
        self.context.framebufferResized = true
        try self.context.updateSwapchain(for: newSize)
    }
    
    public func createWindow(for view: RenderView, size: Vector2i) throws {
        try self.context.createWindow(for: view as! MetalView, size: size)
    }
    
    public func beginFrame() throws {
        try self.context.prepareBuffer()
    }
    
    public func endFrame() throws {
//        try self.context.swapBuffers()
//        try self.context.flush()
    }
    
    // MARK: - Private
}


struct VulkanShader {
    let modules: [ShaderModule]
    var stages: [VkPipelineShaderStageCreateInfo]
}
