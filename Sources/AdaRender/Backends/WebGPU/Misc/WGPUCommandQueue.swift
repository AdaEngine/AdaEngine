//
//  MetalCommandQueue.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

#if canImport(WebGPU)
import WebGPU

final class WGPUCommandQueue: CommandQueue {
    let device: WebGPU.Device

    init(device: WebGPU.Device) {
        self.device = device
    }

    func makeCommandBuffer() -> CommandBuffer {
        WGPUCommandEncoder(device: device)
    }
}
#endif
