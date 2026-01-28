//
//  MetalCommandQueue.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

#if canImport(WebGPU)
import WebGPU

@_spi(Internal)
public final class WGPUCommandQueue: CommandQueue {
    let device: WebGPU.Device

    public init(device: WebGPU.Device) {
        self.device = device
    }

    public func makeCommandBuffer() -> CommandBuffer {
        WGPUCommandEncoder(device: device)
    }
}
#endif
