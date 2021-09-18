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
        try self.context.updateSwapchain(for: newSize)
    }
    
    public func createWindow(for view: RenderView, size: Vector2i) throws {
        try self.context.createWindow(for: view as! MetalView, size: size)
        
        try self.loadShaders()
        try self.createRenderPipeline(frame: size)
    }
    
    public func beginFrame() throws {
        try self.context.prepareBuffer()
    }
    
    public func endFrame() throws {
        try self.context.swapBuffers()
        try self.context.flush()
    }
    
    // MARK: - Private
    
    func createRenderPipeline(frame: Vector2i) throws {
        var stages = self.shaders.first!.stages
        
        var vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            vertexBindingDescriptionCount: 0,
            pVertexBindingDescriptions: nil,
            vertexAttributeDescriptionCount: 0,
            pVertexAttributeDescriptions: nil
        )
        
        var inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            primitiveRestartEnable: false
        )
        
        let viewPort = VkViewport(x: 0, y: 0, width: Float(frame.x), height: Float(frame.y), minDepth: 0, maxDepth: 1)
        let scissor = VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: self.context.swapchain.extent)
        
        var viewportState = VkPipelineViewportStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            viewportCount: 1,
            pViewports: [viewPort],
            scissorCount: 1,
            pScissors: [scissor]
        )
        
        var rasterizer = VkPipelineRasterizationStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            depthClampEnable: false,
            rasterizerDiscardEnable: false,
            polygonMode: VK_POLYGON_MODE_FILL,
            cullMode: VK_CULL_MODE_BACK_BIT.rawValue,
            frontFace: VK_FRONT_FACE_CLOCKWISE,
            depthBiasEnable: false,
            depthBiasConstantFactor: 0,
            depthBiasClamp: 0,
            depthBiasSlopeFactor: 0,
            lineWidth: 1.0
        )
        
        var multisampling = VkPipelineMultisampleStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
            sampleShadingEnable: false,
            minSampleShading: 1,
            pSampleMask: nil,
            alphaToCoverageEnable: false,
            alphaToOneEnable: false
        )
        
        let colorBlendAttachment = VkPipelineColorBlendAttachmentState(
            blendEnable: false,
            srcColorBlendFactor: VK_BLEND_FACTOR_ONE,
            dstColorBlendFactor: VK_BLEND_FACTOR_ZERO,
            colorBlendOp: VK_BLEND_OP_ADD,
            srcAlphaBlendFactor: VK_BLEND_FACTOR_ONE,
            dstAlphaBlendFactor: VK_BLEND_FACTOR_ZERO,
            alphaBlendOp: VK_BLEND_OP_ADD,
            colorWriteMask: VK_COLOR_COMPONENT_R_BIT.rawValue | VK_COLOR_COMPONENT_G_BIT.rawValue | VK_COLOR_COMPONENT_B_BIT.rawValue | VK_COLOR_COMPONENT_A_BIT.rawValue
        )
        
        var colorBlending = VkPipelineColorBlendStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            logicOpEnable: false,
            logicOp: VK_LOGIC_OP_COPY,
            attachmentCount: 1,
            pAttachments: [colorBlendAttachment],
            blendConstants: (0, 0, 0, 0)
        )
        
        var dynamicState = VkPipelineDynamicStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            dynamicStateCount: 2,
            pDynamicStates: [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_LINE_WIDTH]
        )
        
        let pipelineLayout = try PipelineLayout(device: self.context.device)
        let pipelineInfo = VkGraphicsPipelineCreateInfo(
            sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stageCount: UInt32(stages.count),
            pStages: &stages,
            pVertexInputState: &vertexInputInfo,
            pInputAssemblyState: &inputAssembly,
            pTessellationState: nil,
            pViewportState: &viewportState,
            pRasterizationState: &rasterizer,
            pMultisampleState: &multisampling,
            pDepthStencilState: nil,
            pColorBlendState: &colorBlending,
            pDynamicState: nil,
            layout: pipelineLayout.rawPointer,
            renderPass: self.context.renderPass.rawPointer,
            subpass: 0,
            basePipelineHandle: nil,
            basePipelineIndex: -1)
        
        
        let renderPipeline = try RenderPipeline(
            device: self.context.device,
            pipelineLayout: pipelineLayout,
            graphicCreateInfo: pipelineInfo
        )
        
        self.context.graphicsPipeline = renderPipeline
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
            pName: ("main" as NSString).utf8String,
            pSpecializationInfo: nil
        )
        
        let fragStage = VkPipelineShaderStageCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stage: VK_SHADER_STAGE_FRAGMENT_BIT,
            module: fragModule.rawPointer,
            pName: ("main" as NSString).utf8String,
            pSpecializationInfo: nil
        )
        
        self.shaders.append(VulkanShader(modules: [vertModule, fragModule], stages: [vertStage, fragStage]))
    }
}


struct VulkanShader {
    let modules: [ShaderModule]
    var stages: [VkPipelineShaderStageCreateInfo]
}
