//
//  WGPUIndexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import WebGPU

final class WGPUIndexBuffer: WGPUBuffer, IndexBuffer, @unchecked Sendable {

    let indexFormat: IndexBufferFormat
    
    init(buffer: WebGPU.Buffer, device: WebGPU.Device, indexFormat: IndexBufferFormat) {
        self.indexFormat = indexFormat
        
        super.init(buffer: buffer, device: device)
    }
    
}

#endif
