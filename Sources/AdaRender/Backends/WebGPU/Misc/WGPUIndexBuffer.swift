//
//  MetalIndexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)

import Metal

final class WGPUIndexBuffer: MetalBuffer, IndexBuffer, @unchecked Sendable {

    let indexFormat: IndexBufferFormat
    
    init(buffer: MTLBuffer, indexFormat: IndexBufferFormat) {
        self.indexFormat = indexFormat
        
        super.init(buffer: buffer)
    }
    
}

#endif
