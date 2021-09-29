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
        
        let commandBuffer = [commandsBuffer.rawPointer]
        let waitSemaphores = [waitSemaphores.rawPointer]
        let signalSemaphores = [signalSemaphores.rawPointer]
        let stageFlags = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT
        
        VkSubmitInfo.makeSubmit(
            commandBuffers: commandBuffer,
            waitSemaphores: waitSemaphores,
signalSemaphores: signalSemaphores,
            flags: stageFlags) { info in
            withUnsafePointer(to: info) { submitInfo in
                let result = vkQueueSubmit(self.rawPointer, 1, submitInfo, fence.rawPointer)
                if result == VK_SUCCESS {
                    print("congrats")
                }
            }
            
        }
        
        
 
        
//        withUnsafePointer(to: commandsBuffer.rawPointer) { cmdPtr in
//            withUnsafePointer(to: waitSemaphores.rawPointer) { waitPtr in
//                withUnsafePointer(to: signalSemaphores.rawPointer) { signalPtr in
//                    var submitInfo = VkSubmitInfo(
//                        sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
//                        pNext: nil,
//                        waitSemaphoreCount: 1,
//                        pWaitSemaphores: waitPtr,
//                        pWaitDstStageMask: &stageFlags,
//                        commandBufferCount: 1,
//                        pCommandBuffers: cmdPtr,
//                        signalSemaphoreCount: 1,
//                        pSignalSemaphores: signalPtr
//                    )
//
//                    let result = vkQueueSubmit(self.rawPointer, 1, &submitInfo, fence.rawPointer)
//                    if result == VK_SUCCESS {
//                        print("congrats")
//                    }
//                }
//            }
//        }
        
        
        //        try vkCheck(result)
        
    }
    
    func get<T>(_ pointer: UnsafeRawPointer, at index: Int, count: Int) -> T {
        let a = pointer.bindMemory(to: T.self, capacity: count)
        return a[index]
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
