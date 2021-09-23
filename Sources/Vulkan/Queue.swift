//
//  Queue.swift
//  
//
//  Created by v.prusakov on 9/23/21.
//

import CVulkan

final public class Queue {
    
    public let rawPointer: VkQueue
    
    public init?(device: Device, index: UInt32) {
        var queue: VkQueue?
        vkGetDeviceQueue(device.rawPointer, index, 0, &queue)
        
        guard let queue = queue else { return nil }
        self.rawPointer = queue
    }
    
    public func submit(
        commandsBuffer: CommandBuffer,
        waitSemaphores: Semaphore,
        signalSemaphores: Semaphore,
        fence: Fence
    ) throws {
        
        var commandsBuffers = [commandsBuffer.rawPointer]
        var stageFlags: VkPipelineStageFlags = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue
        
        commandsBuffers.withUnsafeBufferPointer { cmdPtr in
            withUnsafePointer(to: waitSemaphores.rawPointer) { waitSemaphores in
                withUnsafePointer(to: signalSemaphores.rawPointer) { signalSemaphores in
                    withUnsafePointer(to: stageFlags) { stageFlags in
                        var submitInfo = VkSubmitInfo(
                            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
                            pNext: nil,
                            waitSemaphoreCount: 1,
                            pWaitSemaphores: waitSemaphores,
                            pWaitDstStageMask: stageFlags,
                            commandBufferCount: 1,
                            pCommandBuffers: cmdPtr.baseAddress,
                            signalSemaphoreCount: 1,
                            pSignalSemaphores: signalSemaphores
                        )
                        
                        let result = vkQueueSubmit(self.rawPointer, 1, &submitInfo, fence.rawPointer)
                        if result == VK_SUCCESS {
                            print("congrats")
                        }
                    }
                }
            }
        }
//        try vkCheck(result)

    }
    
    public func present(for swapchains: [Swapchain], signalSemaphores: [Semaphore], imageIndex: UInt32) throws {
        let swapchain: [VkSwapchainKHR?] = swapchains.map(\.rawPointer)
        let signalSem: [VkSemaphore?] = signalSemaphores.map(\.rawPointer)
        
        var imageIndex = imageIndex
        
        var presentInfo = VkPresentInfoKHR(
            sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            pNext: nil,
            waitSemaphoreCount: 1,
            pWaitSemaphores: signalSem,
            swapchainCount: 1,
            pSwapchains: swapchain,
            pImageIndices: &imageIndex,
            pResults: nil
        )
        
        let result = vkQueuePresentKHR(self.rawPointer, &presentInfo)
        try vkCheck(result)
    }
}
