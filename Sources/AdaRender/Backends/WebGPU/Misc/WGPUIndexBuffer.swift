//
//  WGPUIndexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import WebGPU

@_spi(Internal)
public final class WGPUIndexBuffer: WGPUBuffer, IndexBuffer, @unchecked Sendable {

    public let indexFormat: IndexBufferFormat
    
    init(buffer: WebGPU.Buffer, device: WebGPU.Device, indexFormat: IndexBufferFormat) {
        self.indexFormat = indexFormat
        
        super.init(buffer: buffer, device: device)
    }
    
}

#endif
