//
//  VulkanShader.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

#if VULKAN

import CVulkan
import Vulkan

final class VulkanShader: CompiledShader {

    private(set) var shaderModule: VkShaderModule
    private unowned let device: Device

    init(device: Device, module: VkShaderModule) {
        self.device = device
        self.shaderModule = module
    }

    deinit {
        vkDestroyShaderModule(self.device.rawPointer, shaderModule, nil)
    }
}

extension VulkanShader {
    static func make(from shader: Shader, device: Device) throws -> VulkanShader {
        var shaderModule: VkShaderModule?

        let result = shader.spirvData.withUnsafeBytes { pointer in
            var createInfo = VkShaderModuleCreateInfo(
                sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                codeSize: pointer.count,
                pCode: pointer.baseAddress?.assumingMemoryBound(to: UInt32.self)
            )

            return vkCreateShaderModule(device.rawPointer, &createInfo, nil, &shaderModule)
        }

        guard let shaderModule, result == VK_SUCCESS else {
            throw VulkanError.failedInit(message: "Cannot create shader module", code: result)
        }

        return VulkanShader(device: device, module: shaderModule)
    }
}

#endif
