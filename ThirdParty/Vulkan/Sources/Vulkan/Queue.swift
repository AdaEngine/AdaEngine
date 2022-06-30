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
    
    public func wait() throws {
        let result = vkQueueWaitIdle(self.rawPointer)
        try vkCheck(result)
    }
    
    public func submit(
        commandsBuffers: [CommandBuffer],
        waitSemaphores: [Semaphore] = [],
        signalSemaphores: [Semaphore] = [],
        stageFlags: [UInt32] = [],
        fence: Fence? = nil
    ) throws {
        
        var commandBuffer: [VkCommandBuffer?] = commandsBuffers.map(\.rawPointer)
        var waitSemaphores: [VkQueue?] = waitSemaphores.map(\.rawPointer)
        var signalSemaphores: [VkQueue?] = signalSemaphores.map(\.rawPointer)
        var stageFlags: [UInt32] = stageFlags
 
        var submitInfo = VkSubmitInfo(
            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
            pNext: nil,
            waitSemaphoreCount: UInt32(waitSemaphores.count),
            pWaitSemaphores: &waitSemaphores,
            pWaitDstStageMask: &stageFlags,
            commandBufferCount: UInt32(commandBuffer.count),
            pCommandBuffers: &commandBuffer,
            signalSemaphoreCount: UInt32(signalSemaphores.count),
            pSignalSemaphores: &signalSemaphores
        )
        
        let result = vkQueueSubmit(self.rawPointer, 1, &submitInfo, fence?.rawPointer)
        try vkCheck(result)
        
    }
    
    func get<T>(_ pointer: UnsafeRawPointer, at index: Int, count: Int) -> T {
        let a = pointer.bindMemory(to: T.self, capacity: count)
        return a[index]
    }
    
    public func present(swapchains: [Swapchain], waitSemaphores: [Semaphore], imageIndex: UInt32) throws {
        let swapchains: [VkSwapchainKHR?] = swapchains.map(\.rawPointer)
        var waitSemaphores: [VkSemaphore?] = waitSemaphores.map(\.rawPointer)
        
        var imageIndex = imageIndex
        
        var presentInfo = VkPresentInfoKHR(
            sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            pNext: nil,
            waitSemaphoreCount: UInt32(waitSemaphores.count),
            pWaitSemaphores: &waitSemaphores,
            swapchainCount: UInt32(swapchains.count),
            pSwapchains: swapchains,
            pImageIndices: &imageIndex,
            pResults: nil
        )
        
        let result = vkQueuePresentKHR(self.rawPointer, &presentInfo)
        try vkCheck(result)
    }
}

fileprivate extension VkSubmitInfo {
    
    
    static func makeSubmit(
        commandBuffers: [VkCommandBuffer?],
        waitSemaphores: [VkSemaphore?],
        signalSemaphores: [VkSemaphore?],
        flags: VkPipelineStageFlagBits,
        completion: (VkSubmitInfo) -> Void
    ) {
        
        commandBuffers.withUnsafeBufferPointer { cmd in
            waitSemaphores.withUnsafeBufferPointer { wait in
                signalSemaphores.withUnsafeBufferPointer { signal in
                    withUnsafePointer(to: flags.rawValue) { flags in
                        
                        let submitInfo = VkSubmitInfo(
                            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
                            pNext: nil,
                            waitSemaphoreCount: UInt32(waitSemaphores.count),
                            pWaitSemaphores: wait.baseAddress,
                            pWaitDstStageMask: flags,
                            commandBufferCount: UInt32(commandBuffers.count),
                            pCommandBuffers: cmd.baseAddress,
                            signalSemaphoreCount: UInt32(signalSemaphores.count),
                            pSignalSemaphores: signal.baseAddress
                        )
                        
                        completion(submitInfo)
                    }
                }
            }
        }
    }
    
}
