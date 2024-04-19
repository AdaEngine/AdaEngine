//
//  RenderPass.swift
//  
//
//  Created by v.prusakov on 8/17/21.
//

import CVulkan

public class RenderPass {
    
    public let rawPointer: VkRenderPass
    public unowned let device: Device
    
    public init(device: Device, createInfo: VkRenderPassCreateInfo) throws {
        var pointer: VkRenderPass?
        
        let result = withUnsafePointer(to: createInfo) { infoPtr in
            vkCreateRenderPass(device.rawPointer, infoPtr, nil, &pointer)
        }
        
        guard let pointer = pointer, result == VK_SUCCESS else {
            throw VKError(code: result, message: "Could not create VkRenderPass")
        }
        
        self.rawPointer = pointer
        self.device = device
    }
    
    public func begin(for cmd: CommandBuffer, framebuffer: Framebuffer, swapchain: Swapchain) {
        var clearColor = VkClearValue()
        clearColor.color = VkClearColorValue(float32: (0, 0, 0, 1))
        
        let info = VkRenderPassBeginInfo(
            sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            pNext: nil,
            renderPass: self.rawPointer,
            framebuffer: framebuffer.rawPointer,
            renderArea: VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: swapchain.extent),
            clearValueCount: 1,
            pClearValues: &clearColor
        )
        
        withUnsafePointer(to: info) { ptr in
            vkCmdBeginRenderPass(cmd.rawPointer, ptr, VK_SUBPASS_CONTENTS_INLINE)
        }
    }
    
    public func end(for cmd: CommandBuffer) {
        vkCmdEndRenderPass(cmd.rawPointer)
    }
    
    deinit {
        vkDestroyRenderPass(self.device.rawPointer, self.rawPointer, nil)
    }
    
}
