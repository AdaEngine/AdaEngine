//
//  MetalCommandQueue.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

#if WEBGPU_ENABLED && canImport(WebGPU)
    @unsafe @preconcurrency import WebGPU

    @_spi(Internal)
    public final class WGPUCommandQueue: CommandQueue {
        let device: WebGPU.GPUDevice
        private let spatialScaler: WGPUFSRSpatialScaler

        public init(device: WebGPU.GPUDevice) {
            self.device = device
            self.spatialScaler = WGPUFSRSpatialScaler()
        }

        init(device: WebGPU.GPUDevice, spatialScaler: WGPUFSRSpatialScaler) {
            self.device = device
            self.spatialScaler = spatialScaler
        }

        public func makeCommandBuffer() -> CommandBuffer {
            WGPUCommandEncoder(device: device, spatialScaler: spatialScaler)
        }
    }
#endif
