//
//  MetalCommandQueue.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

#if canImport(WebGPU)
import WebGPU

final class WGPUCommandQueue: CommandQueue {
    let commandQueue: WebGPU.Queue

    init(commandQueue: WebGPU.Queue) {
        self.commandQueue = commandQueue
    }

    func makeCommandBuffer() -> CommandBuffer {
        
        fatalError()
        // guard let commandBuffer = commandQueue.makeCommandBuffer() else {
        //     fatalError("MetalCommandQueue failed. Can't create MTLCommandBuffer.")
        // }
        // return MetalCommandEncoder(commandBuffer: commandBuffer)
    }
}
#endif
