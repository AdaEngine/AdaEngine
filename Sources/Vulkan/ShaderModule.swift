//
//  ShaderModule.swift
//  
//
//  Created by v.prusakov on 9/10/21.
//

import CVulkan
import Foundation

public final class ShaderModule {
    
    public let rawPointer: VkShaderModule
    private unowned let device: Device
    
    public init(device: Device, shaderData: Data) throws {
        
        var shaderModule: VkShaderModule?
        
        let result = shaderData.withUnsafeBytes { pointer -> VkResult in
            let buffer = pointer.bindMemory(to: UInt32.self)
            
            let info = VkShaderModuleCreateInfo(
                sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                codeSize: buffer.count,
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
