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
        try self.loadShaders()
        try self.context.updateSwapchain(for: newSize)
    }
    
    public func createWindow(for view: RenderView, size: Vector2i) throws {
        try self.context.createWindow(for: view as! MetalView, size: size)
    }
    
    public func beginFrame() throws {
        
    }
    
    public func endFrame() throws {
        
    }
    
    private func loadShaders() throws {
        let frag = try! Data(contentsOf: Bundle.module.url(forResource: "shader.frag", withExtension: "spv")!)
        let vert = try! Data(contentsOf: Bundle.module.url(forResource: "shader.vert", withExtension: "spv")!)
        let vertModule = try ShaderModule(device: self.context.device, shaderData: vert)
        let fragModule = try ShaderModule(device: self.context.device, shaderData: frag)
        
        let vertStage = VkPipelineShaderStageCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stage: VK_SHADER_STAGE_VERTEX_BIT,
            module: vertModule.rawPointer,
            pName: "main",
            pSpecializationInfo: nil
        )
        
        let fragStage = VkPipelineShaderStageCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stage: VK_SHADER_STAGE_FRAGMENT_BIT,
            module: fragModule.rawPointer,
            pName: "main",
            pSpecializationInfo: nil
        )
        
        self.shaders.append(VulkanShader(stages: [vertStage, fragStage]))
    }
}


struct VulkanShader {
    var stages: [VkPipelineShaderStageCreateInfo]
}
