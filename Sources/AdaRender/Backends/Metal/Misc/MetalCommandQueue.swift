//
//  MetalCommandQueue.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

#if canImport(Metal)
import Metal

final class MetalCommandQueue: CommandQueue {

    let commandQueue: MTLCommandQueue

    init(commandQueue: MTLCommandQueue) {
        self.commandQueue = commandQueue
    }

    func makeCommandBuffer() -> CommandBuffer {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError()
        }
        return MetalCommandEncoder(commandBuffer: commandBuffer)
    }
}
#endif
