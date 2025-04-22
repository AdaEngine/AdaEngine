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
    private unowned let shader: Shader
    
    private(set) var descriptorSetLayouts = [VkDescriptorSetLayout]()
    private var poolTypes = [Int: [VkDescriptorPoolSize]]()
    private var writeDescriptorSet = [VkWriteDescriptorSet]()
    
    init(device: Device, shader: Shader, module: VkShaderModule) {
        self.device = device
        self.shader = shader
        self.shaderModule = module
        
        self.invalidateDescriptors()
    }
    
    deinit {
        vkDestroyShaderModule(self.device.rawPointer, shaderModule, nil)
    }
    
    func invalidateDescriptors() {
        descriptorSetLayouts.removeAll()
        poolTypes.removeAll()
        writeDescriptorSet.removeAll()
        
        for (index, item) in shader.reflectionData.descriptorSets.enumerated() {
            if !item.uniformsBuffers.isEmpty {
                poolTypes[index, default: []].append(
                    VkDescriptorPoolSize(
                        type: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                        descriptorCount: UInt32(item.uniformsBuffers.count)
                    )
                )
            }
            
            if !item.constantBuffers.isEmpty {
                poolTypes[index, default: []].append(
                    VkDescriptorPoolSize(
                        type: VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC,
                        descriptorCount: UInt32(item.uniformsBuffers.count)
                    )
                )
            }
            
            if !item.sampledImages.isEmpty {
                poolTypes[index, default: []].append(
                    VkDescriptorPoolSize(
                        type: VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
                        descriptorCount: UInt32(item.uniformsBuffers.count)
                    )
                )
            }
            
            var layoutBindings = [VkDescriptorSetLayoutBinding]()
            
            for (binding, buffer) in item.uniformsBuffers {
                let layout = VkDescriptorSetLayoutBinding(
                    binding: UInt32(binding),
                    descriptorType: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                    descriptorCount: 1,
                    stageFlags: buffer.shaderStage.rawValue,
                    pImmutableSamplers: nil
                )
                
                let set = VkWriteDescriptorSet(
                    sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                    pNext: nil,
                    dstSet: nil,
                    dstBinding: layout.binding,
                    dstArrayElement: 0,
                    descriptorCount: 1,
                    descriptorType: layout.descriptorType,
                    pImageInfo: nil,
                    pBufferInfo: nil,
                    pTexelBufferView: nil
                )
                
                layoutBindings.append(layout)
                writeDescriptorSet.append(set)
            }
            
//            for (binding, buffer) in item.constantBuffers {
//                
//            }
            
            for (binding, sampler) in item.sampledImages {
                let layout = VkDescriptorSetLayoutBinding(
                    binding: UInt32(binding),
                    descriptorType: VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
                    descriptorCount: UInt32(sampler.arraySize),
                    stageFlags: sampler.shaderStage.rawValue,
                    pImmutableSamplers: nil
                )
                
                let set = VkWriteDescriptorSet(
                    sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                    pNext: nil,
                    dstSet: nil,
                    dstBinding: layout.binding,
                    dstArrayElement: 0,
                    descriptorCount: 1,
                    descriptorType: layout.descriptorType,
                    pImageInfo: nil,
                    pBufferInfo: nil,
                    pTexelBufferView: nil
                )
                
                layoutBindings.append(layout)
                writeDescriptorSet.append(set)
            }
            
            var createInfo = VkDescriptorSetLayoutCreateInfo(
                sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
                pNext: nil,
                flags: 0,
                bindingCount: UInt32(layoutBindings.count),
                pBindings: &layoutBindings
            )
            
            var descriptorSetLayout: VkDescriptorSetLayout?
            let result = vkCreateDescriptorSetLayout(self.device.rawPointer, &createInfo, nil, &descriptorSetLayout)
            
            if let descriptorSetLayout, result == VK_SUCCESS {
                descriptorSetLayouts.append(descriptorSetLayout)
            } else {
                assertionFailure("Couldn't create VkDescriptorSetLayout with result code: \(result)")
            }
        }
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
        
        return VulkanShader(device: device, shader: shader, module: shaderModule)
    }
}

#endif
