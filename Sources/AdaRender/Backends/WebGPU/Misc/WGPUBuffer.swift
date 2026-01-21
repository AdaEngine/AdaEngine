//
//  MetalBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import WebGPU
import CWebGPU

@_spi(Internal)
public class WGPUBuffer: Buffer, @unchecked Sendable {
    let buffer: WebGPU.Buffer
    let device: WebGPU.Device
    
    public var label: String? {
        didSet {
            self.buffer.setLabel(label ?? "")
        }
    }
    
    init(buffer: WebGPU.Buffer, device: WebGPU.Device) {
        self.buffer = buffer
        self.device = device
    }
    
    public var length: Int { return Int(buffer.size) }
    
    public func contents() -> UnsafeMutableRawPointer { 
        unsafe self.buffer.getMappedRange()
    }
    
    public func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        unsafe device.queue.writeBuffer(
            self.buffer, 
            bufferOffset: UInt64(offset), 
            data: UnsafeRawBufferPointer(start: bytes, count: byteCount)
        )
    }
}

#endif
