//
//  VulkanRenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/19/24.
//

#if VULKAN

import CVulkan
import Vulkan

class VulkanRenderPipeline: RenderPipeline {

    let descriptor: RenderPipelineDescriptor
    private unowned let device: Device
    private(set) var renderPipeline: VkPipeline!

    init(device: Device, descriptor: RenderPipelineDescriptor) throws {
        let holder = VulkanUtils.TemporaryBufferHolder(label: "VulkanRenderPipeline init")

        self.descriptor = descriptor
        self.device = device

        let stages = try [descriptor.vertex, descriptor.fragment]
            .compactMap { $0 }
            .map { try Self.makeShaderStageCreateInfo(from: $0, holder: holder) }

        let stagesPtr = holder.unsafePointerCopy(collection: stages)

        let depthStencil = descriptor.depthStencilDescriptor.map {
            holder.unsafePointerCopy(from: Self.makeVkPipelineDepthStencilStateInfo(for: $0))
        }

        let vertexInputState = Self.makeVkPipelineVertexInputStateCreateInfo(for: descriptor, holder: holder)

        var createInfo = VkGraphicsPipelineCreateInfo(
            sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stageCount: UInt32(stages.count),
            pStages: stagesPtr,
            pVertexInputState: holder.unsafePointerCopy(from: vertexInputState),
            pInputAssemblyState: nil,
            pTessellationState: nil,
            pViewportState: nil,//UnsafePointer<VkPipelineViewportStateCreateInfo>!,
            pRasterizationState: nil,//UnsafePointer<VkPipelineRasterizationStateCreateInfo>!,
            pMultisampleState: nil,//UnsafePointer<VkPipelineMultisampleStateCreateInfo>!,
            pDepthStencilState: depthStencil,
            pColorBlendState: nil,//UnsafePointer<VkPipelineColorBlendStateCreateInfo>!,
            pDynamicState: nil,//UnsafePointer<VkPipelineDynamicStateCreateInfo>!,
            layout: nil,//VkPipelineLayout!,
            renderPass: nil,//VkRenderPass!,
            subpass: UInt32(0),
            basePipelineHandle: nil,//VkPipeline!,
            basePipelineIndex: Int32(0)
        )

        var renderPipeline: VkPipeline?

        let result = withUnsafePointer(to: &createInfo) { ptr in
            vkCreateGraphicsPipelines(device.rawPointer, nil, 1, ptr, nil, &renderPipeline)
        }

        guard let renderPipeline, result == VK_SUCCESS else {
            throw VulkanError.failedInit(code: result)
        }

        self.renderPipeline = renderPipeline
    }

    deinit {
        vkDestroyPipeline(self.device.rawPointer, renderPipeline, nil)
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

        let attributes = descriptor.vertexDescriptor.attributes.map { attribute in
            VkVertexInputAttributeDescription(
                location: UInt32(attribute.bufferIndex),
                binding: UInt32(attribute.bufferIndex),
                format: attribute.format.toVulkan,
                offset: UInt32(attribute.offset)
            )
        }

        return VkPipelineVertexInputStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            vertexBindingDescriptionCount: UInt32(layouts.count),
            pVertexBindingDescriptions: holder.unsafePointerCopy(collection: layouts),
            vertexAttributeDescriptionCount: UInt32(attributes.count),
            pVertexAttributeDescriptions: holder.unsafePointerCopy(collection: attributes)
        )
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

#endif
