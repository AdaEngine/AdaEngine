//
//  MetalVertexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/31/23.
//

#if canImport(WebGPU)
import WebGPU

@_spi(Internal)
public final class WGPUVertexBuffer: WGPUBuffer, VertexBuffer, @unchecked Sendable {
    
    public var binding: Int
    
    init(buffer: WebGPU.Buffer, device: WebGPU.Device, binding: Int) {
        self.binding = binding
        super.init(buffer: buffer, device: device)
    }
}
#endif
