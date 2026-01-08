//
//  MetalVertexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/31/23.
//

#if canImport(WebGPU)
import WebGPU

final class WGPUVertexBuffer: WGPUBuffer, VertexBuffer, @unchecked Sendable {
    
    var binding: Int
    let offset: Int
    
    init(buffer: WebGPU.Buffer, device: WebGPU.Device, binding: Int, offset: Int) {
        self.binding = binding
        self.offset = offset
        super.init(buffer: buffer, device: device)
    }
}
#endif
