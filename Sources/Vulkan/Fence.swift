//
//  Fence.swift
//  
//
//  Created by v.prusakov on 9/10/21.
//

import CVulkan

public class Fence {
    
    public let rawPointer: VkFence
    private unowned let device: Device
    
    var isSignaled = false
    
    public init(device: Device) throws {
        var fence: VkFence?
        
        let info = VkFenceCreateInfo(
            sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            pNext: nil,
            flags: VK_FENCE_CREATE_SIGNALED_BIT.rawValue
        )
        
        let result = withUnsafePointer(to: info) { ptr in
            vkCreateFence(device.rawPointer, ptr, nil, &fence)
        }
        
        try vkCheck(result, "Failed when creating fence")
        
        self.device = device
        self.rawPointer = fence!
    }
    
    public func wait(timeout: UInt64 = .max) throws {
        guard !self.isSignaled else {
            return // fence was signaled should wait
        }
        
        var fence: VkFence? = self.rawPointer
        let result = vkWaitForFences(self.device.rawPointer, 1, &fence, true, timeout)
        
        switch result {
        case VK_SUCCESS:
            self.isSignaled = true
        case VK_TIMEOUT:
            return
        default:
            try vkCheck(result)
        }
    }
    
    public func reset() throws {
        guard self.isSignaled else { return }
        var fence: VkFence? = self.rawPointer
        let result = vkResetFences(self.device.rawPointer, 1, &fence)
        try vkCheck(result)
        
        self.isSignaled = false
    }
    
    deinit {
        vkDestroyFence(self.device.rawPointer, self.rawPointer, nil)
    }
}
