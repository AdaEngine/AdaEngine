//
//  ShaderModule.swift
//  
//
//  Created by v.prusakov on 9/10/21.
//

import CVulkan
import Foundation

/// A shader module.
public final class ShaderModule {
    
    /// The raw pointer to the shader module.
    public let rawPointer: VkShaderModule
    
    /// The device that owns the shader module.
    private unowned let device: Device
    
    /// Initialize a new shader module.
    ///
    /// - Parameters:
    ///   - device: The device that owns the shader module.
    public init(device: Device, shaderData: Data) throws {
        
        var shaderModule: VkShaderModule?
        
        let result = shaderData.withUnsafeBytes { pointer -> VkResult in
            let buffer = pointer.bindMemory(to: UInt32.self)
            
            let info = VkShaderModuleCreateInfo(
                sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                codeSize: buffer.count * 4, // Codesize must be a multiple of 4
                pCode: buffer.baseAddress
            )
            
            return withUnsafePointer(to: info) { infoPtr in
                vkCreateShaderModule(device.rawPointer, infoPtr, nil, &shaderModule)
            }
        }
        
        try vkCheck(result)
        
        self.rawPointer = shaderModule!
        self.device = device
    }
    
    deinit {
        vkDestroyShaderModule(self.device.rawPointer, self.rawPointer, nil)
    }
}
