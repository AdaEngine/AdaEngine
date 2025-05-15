//
//  VulkanRenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/19/24.
//

#if VULKAN

import CVulkan
import Vulkan

final class VulkanRenderPipeline: RenderPipeline, @unchecked Sendable {

    let descriptor: RenderPipelineDescriptor
    private unowned let device: Device
    private(set) var renderPipeline: VkPipeline!
    private(set) var pipelineLayout: Vulkan.PipelineLayout!

    init(device: Device, descriptor: RenderPipelineDescriptor) throws {
        self.descriptor = descriptor
        self.device = device
    }

    deinit {
        vkDestroyPipeline(self.device.rawPointer, renderPipeline, nil)
    }
    
    func update(for framebuffer: VulkanFramebuffer, drawList: DrawList) throws {
        let holder = VulkanUtils.TemporaryBufferHolder(label: "VulkanRenderPipeline init")
        
        let stages = try [descriptor.vertex, descriptor.fragment]
            .compactMap { $0 }
            .map { try Self.makeShaderStageCreateInfo(from: $0, holder: holder) }

        let stagesPtr = holder.unsafePointerCopy(collection: stages)

        let depthStencil = descriptor.depthStencilDescriptor.map {
            holder.unsafePointerCopy(from: Self.makeVkPipelineDepthStencilStateInfo(for: $0))
        }

        let vertexInputState = Self.makeVkPipelineVertexInputStateCreateInfo(for: descriptor, holder: holder)
        
        let vertexDescriptorSetLayouts = (descriptor.vertex.compiledShader as! VulkanShader).descriptorSetLayouts
        let fragmentDescriptorSetLayouts = (descriptor.fragment.compiledShader as! VulkanShader).descriptorSetLayouts
        
        let setLayouts: [VkDescriptorSetLayout?] = vertexDescriptorSetLayouts + fragmentDescriptorSetLayouts
        
        let pSetLayouts = holder.unsafePointerCopy(collection: setLayouts)
        
        var layoutCreateInfo = VkPipelineLayoutCreateInfo()
        layoutCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
        layoutCreateInfo.setLayoutCount = UInt32(setLayouts.count)
        layoutCreateInfo.pSetLayouts = pSetLayouts
        layoutCreateInfo.pushConstantRangeCount = 0
        layoutCreateInfo.pPushConstantRanges = nil
        
        let pipelineLayout = try PipelineLayout(device: self.device, createInfo: layoutCreateInfo)
        
        var dynamicStates: [VkDynamicState] = [
            VK_DYNAMIC_STATE_VIEWPORT,
            VK_DYNAMIC_STATE_SCISSOR
        ]
        
        if descriptor.primitive == .line || descriptor.primitive == .lineStrip {
            dynamicStates.append(VK_DYNAMIC_STATE_LINE_WIDTH)
        }
        
        let pDynamicStates = holder.unsafePointerCopy(collection: dynamicStates)
        
        var dynamicState = VkPipelineDynamicStateCreateInfo()
        dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO
        dynamicState.dynamicStateCount = UInt32(dynamicStates.count)
        dynamicState.pDynamicStates = pDynamicStates
        
        var multisampleState = VkPipelineMultisampleStateCreateInfo()
        multisampleState.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
        multisampleState.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
        
        let colorBlendState = Self.makeColorBlendAttachmentStateCreateInfo(for: descriptor, framebuffer: framebuffer, holder: holder)
        
        var viewportState = VkPipelineViewportStateCreateInfo()
        viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
        viewportState.viewportCount = 1
        viewportState.scissorCount = 1
        
        var rasterizationState = VkPipelineRasterizationStateCreateInfo()
        rasterizationState.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
        rasterizationState.polygonMode = drawList.triangleFillMode == .fill ? VK_POLYGON_MODE_FILL : VK_POLYGON_MODE_LINE
        rasterizationState.cullMode = descriptor.backfaceCulling ? VK_CULL_MODE_BACK_BIT.rawValue : VK_CULL_MODE_NONE.rawValue
        rasterizationState.frontFace = VK_FRONT_FACE_CLOCKWISE
        rasterizationState.depthClampEnable = false
        rasterizationState.rasterizerDiscardEnable = false
        rasterizationState.depthBiasEnable = false
        rasterizationState.lineWidth = drawList.lineWidth ?? 1
        
        let pRasterizationState = holder.unsafePointerCopy(from: rasterizationState)
        let pViewportState = holder.unsafePointerCopy(from: viewportState)
        let pColorBlendState = holder.unsafePointerCopy(from: colorBlendState)
        let pMultisampleState = holder.unsafePointerCopy(from: multisampleState)
        let pDynamicState = holder.unsafePointerCopy(from: dynamicState)

        var createInfo = VkGraphicsPipelineCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
        createInfo.stageCount = UInt32(stages.count)
        createInfo.pStages = stagesPtr
        createInfo.pVertexInputState = holder.unsafePointerCopy(from: vertexInputState)
        createInfo.pViewportState = pViewportState
        createInfo.pRasterizationState = pRasterizationState
        createInfo.pMultisampleState = pMultisampleState
        createInfo.pDepthStencilState = depthStencil
        createInfo.pColorBlendState = pColorBlendState
        createInfo.pDynamicState = pDynamicState
        createInfo.layout = pipelineLayout.rawPointer
        createInfo.renderPass = framebuffer.renderPass.rawPointer

        var renderPipeline: VkPipeline?

        let result = withUnsafePointer(to: &createInfo) { ptr in
            vkCreateGraphicsPipelines(device.rawPointer, nil, 1, ptr, nil, &renderPipeline)
        }

        guard let renderPipeline, result == VK_SUCCESS else {
            throw VulkanError.failedInit(code: result)
        }
        
        self.renderPipeline = renderPipeline
        self.pipelineLayout = pipelineLayout
    }

    // MARK: - Static

    private static func makeShaderStageCreateInfo(from shader: Shader, holder: VulkanUtils.TemporaryBufferHolder) throws -> VkPipelineShaderStageCreateInfo {
        guard let compiledShader = shader.compiledShader as? VulkanShader else {
            throw VulkanError.failedInit(message: "CompiledShader not is a VulkanShader class.", code: VK_ERROR_UNKNOWN)
        }

        let name = holder.unsafePointerCopy(string: shader.entryPoint)

        let createInfo = VkPipelineShaderStageCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stage: shader.stage.toVulkan,
            module: compiledShader.shaderModule,
            pName: name,
            pSpecializationInfo: nil
        )

        return createInfo
    }
    
    private static func makeColorBlendAttachmentStateCreateInfo(
        for descriptor: RenderPipelineDescriptor,
        framebuffer: VulkanFramebuffer,
        holder: VulkanUtils.TemporaryBufferHolder
    ) -> VkPipelineColorBlendStateCreateInfo {
        
        var colorAttachments: [VkPipelineColorBlendAttachmentState] = []
        
        if framebuffer.isScreenBuffer {
            
            var state = VkPipelineColorBlendAttachmentState()
            state.colorWriteMask = 0xf
            state.blendEnable = true
            state.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA
            state.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
            state.colorBlendOp = VK_BLEND_OP_ADD
            state.alphaBlendOp = VK_BLEND_OP_ADD
            state.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE
            state.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO
            
            colorAttachments.append(state)
        } else {
            for attachment in descriptor.colorAttachments {
                var state = VkPipelineColorBlendAttachmentState()
                state.blendEnable = attachment.isBlendingEnabled ? VK_TRUE : VK_FALSE
                state.alphaBlendOp = attachment.alphaBlendOperation.toVulkan
                state.srcAlphaBlendFactor = attachment.sourceAlphaBlendFactor.toVulkan
                state.dstAlphaBlendFactor = attachment.destinationAlphaBlendFactor.toVulkan
                state.colorBlendOp = attachment.rgbBlendOperation.toVulkan
                state.srcColorBlendFactor = attachment.sourceRGBBlendFactor.toVulkan
                state.dstColorBlendFactor = attachment.destinationRGBBlendFactor.toVulkan
                
                colorAttachments.append(state)
            }
        }
        
        let pAttachments = holder.unsafePointerCopy(collection: colorAttachments)
        
        var createInfo = VkPipelineColorBlendStateCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
        createInfo.attachmentCount = UInt32(colorAttachments.count)
        createInfo.pAttachments = pAttachments
        return createInfo
    }

    private static func makeVkPipelineVertexInputStateCreateInfo(
        for descriptor: RenderPipelineDescriptor,
        holder: VulkanUtils.TemporaryBufferHolder
    ) -> VkPipelineVertexInputStateCreateInfo {

        let layouts = descriptor.vertexDescriptor.layouts.map { layout in
            VkVertexInputBindingDescription(
                binding: 0,
                stride: UInt32(layout.stride),
                inputRate: VK_VERTEX_INPUT_RATE_VERTEX
            )
        }
        
        let attributes = descriptor.vertexDescriptor.attributes.enumerated().map { (index, attribute) in
            VkVertexInputAttributeDescription(
                location: UInt32(index),
                binding: UInt32(attribute.bufferIndex),
                format: attribute.format.toVulkan,
                offset: UInt32(attribute.offset)
            )
        }

        var createInfo = VkPipelineVertexInputStateCreateInfo()
        createInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
        createInfo.vertexBindingDescriptionCount = UInt32(layouts.count)
        createInfo.pVertexBindingDescriptions = holder.unsafePointerCopy(collection: layouts)
        createInfo.vertexAttributeDescriptionCount = UInt32(attributes.count)
        createInfo.pVertexAttributeDescriptions = holder.unsafePointerCopy(collection: attributes)
        
        return createInfo
    }

    private static func makeVkPipelineDepthStencilStateInfo(for descriptor: DepthStencilDescriptor) -> VkPipelineDepthStencilStateCreateInfo {

        let stencilDescriptor = descriptor.stencilOperationDescriptor

        let front = VkStencilOpState(
            failOp: stencilDescriptor?.fail.toVulkan ?? VK_STENCIL_OP_ZERO,
            passOp: stencilDescriptor?.pass.toVulkan ?? VK_STENCIL_OP_ZERO,
            depthFailOp: stencilDescriptor?.depthFail.toVulkan ?? VK_STENCIL_OP_ZERO,
            compareOp: stencilDescriptor?.compare.toVulkan ?? VK_COMPARE_OP_NEVER,
            compareMask: UInt32(0),
            writeMask: UInt32(stencilDescriptor?.writeMask ?? 0),
            reference: 0
        )

        return VkPipelineDepthStencilStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            depthTestEnable: descriptor.isDepthTestEnabled ? VK_TRUE : VK_FALSE,
            depthWriteEnable: descriptor.isDepthWriteEnabled ? VK_TRUE : VK_FALSE,
            depthCompareOp: descriptor.depthCompareOperator.toVulkan,
            depthBoundsTestEnable: descriptor.isDepthRangeEnabled ? VK_TRUE : VK_FALSE,
            stencilTestEnable: descriptor.isEnableStencil ? VK_TRUE : VK_FALSE,
            front: front,
            back: front,
            minDepthBounds: descriptor.depthRangeMin,
            maxDepthBounds: descriptor.depthRangeMax
        )
    }
}

extension CompareOperation {
    var toVulkan: VkCompareOp {
        switch self {
        case .never:
            return VK_COMPARE_OP_NEVER
        case .always:
            return VK_COMPARE_OP_ALWAYS
        case .equal:
            return VK_COMPARE_OP_EQUAL
        case .notEqual:
            return VK_COMPARE_OP_NOT_EQUAL
        case .less:
            return VK_COMPARE_OP_LESS
        case .lessOrEqual:
            return VK_COMPARE_OP_LESS_OR_EQUAL
        case .greater:
            return VK_COMPARE_OP_GREATER
        case .greaterOrEqual:
            return VK_COMPARE_OP_GREATER_OR_EQUAL
        }
    }
}

extension StencilOperation {
    var toVulkan: VkStencilOp {
        switch self {
        case .zero:
            return VK_STENCIL_OP_ZERO
        case .keep:
            return VK_STENCIL_OP_KEEP
        case .replace:
            return VK_STENCIL_OP_REPLACE
        case .incrementAndClamp:
            return VK_STENCIL_OP_INCREMENT_AND_CLAMP
        case .decrementAndClamp:
            return VK_STENCIL_OP_DECREMENT_AND_CLAMP
        case .invert:
            return VK_STENCIL_OP_INVERT
        case .incrementAndWrap:
            return VK_STENCIL_OP_INCREMENT_AND_WRAP
        case .decrementAndWrap:
            return VK_STENCIL_OP_DECREMENT_AND_WRAP
        }
    }
}

extension ShaderStage {
    var toVulkan: VkShaderStageFlagBits {
        switch self {
        case .vertex:
            return VK_SHADER_STAGE_VERTEX_BIT
        case .fragment:
            return VK_SHADER_STAGE_FRAGMENT_BIT
        case .compute:
            return VK_SHADER_STAGE_COMPUTE_BIT
        case .tesselationControl:
            return VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT
        case .tesselationEvaluation:
            return VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT
        case .max:
            return VK_SHADER_STAGE_FLAG_BITS_MAX_ENUM
        }
    }
}

extension BlendFactor {
    var toVulkan: VkBlendFactor {
        switch self {
        case .zero:
            return VK_BLEND_FACTOR_ZERO
        case .one:
            return VK_BLEND_FACTOR_ONE
        case .sourceColor:
            return VK_BLEND_FACTOR_SRC_COLOR
        case .oneMinusSourceColor:
            return VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR
        case .sourceAlpha:
            return VK_BLEND_FACTOR_SRC_ALPHA
        case .oneMinusSourceAlpha:
            return VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
        case .destinationColor:
            return VK_BLEND_FACTOR_DST_COLOR
        case .oneMinusDestinationColor:
            return VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR
        case .destinationAlpha:
            return VK_BLEND_FACTOR_DST_ALPHA
        case .oneMinusDestinationAlpha:
            return VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA
        case .sourceAlphaSaturated:
            return VK_BLEND_FACTOR_SRC_ALPHA_SATURATE
        case .blendColor:
            return VK_BLEND_FACTOR_CONSTANT_COLOR
        case .oneMinusBlendColor:
            return VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR
        case .blendAlpha:
            return VK_BLEND_FACTOR_CONSTANT_ALPHA
        case .oneMinusBlendAlpha:
            return VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA
        }
    }
}

extension BlendOperation {
    var toVulkan: VkBlendOp {
        switch self {
        case .add:
            return VK_BLEND_OP_ADD
        case .subtract:
            return VK_BLEND_OP_SUBTRACT
        case .reverseSubtract:
            return VK_BLEND_OP_REVERSE_SUBTRACT
        case .min:
            return VK_BLEND_OP_MIN
        case .max:
            return VK_BLEND_OP_MAX
        }
    }
}

#endif
