//
//  VulkanSampler.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

#if VULKAN
import CVulkan
import Vulkan

final class VulkanSampler: Sampler {
    
    var descriptor: SamplerDescriptor

    private(set) var sampler: VkSampler!
    private unowned let device: Device

    init(device: Device, descriptor: SamplerDescriptor) throws {
        self.descriptor = descriptor
        self.device = device

        var createInfo = VkSamplerCreateInfo(
            sType: VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            pNext: nil,
            flags: 0,
            magFilter: descriptor.magFilter == .linear ? VK_FILTER_LINEAR : VK_FILTER_NEAREST,
            minFilter: descriptor.minFilter == .linear ? VK_FILTER_LINEAR : VK_FILTER_NEAREST,
            mipmapMode: descriptor.mipFilter == .linear ? VK_SAMPLER_MIPMAP_MODE_LINEAR : VK_SAMPLER_MIPMAP_MODE_NEAREST,
            addressModeU: VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            addressModeV: VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            addressModeW: VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
            mipLodBias: 0.0,
            anisotropyEnable: VK_FALSE,
            maxAnisotropy: 1.0,
            compareEnable: VK_FALSE,
            compareOp: VK_COMPARE_OP_ALWAYS,
            minLod: descriptor.lodMinClamp,
            maxLod: descriptor.lodMaxClamp,
            borderColor: VK_BORDER_COLOR_FLOAT_OPAQUE_BLACK,
            unnormalizedCoordinates: VK_FALSE
        )

        let result = vkCreateSampler(device.rawPointer, &createInfo, nil, &sampler)

        if result != VK_SUCCESS {
            throw VulkanError.failedInit(code: result)
        }
    }

    deinit {
        vkDestroySampler(self.device.rawPointer, sampler, nil)
    }
}

#endif
