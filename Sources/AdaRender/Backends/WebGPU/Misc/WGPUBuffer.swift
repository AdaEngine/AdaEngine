//
//  MetalBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import WebGPU
import CWebGPU

class WGPUBuffer: Buffer, @unchecked Sendable {
    let buffer: WebGPU.Buffer
    let device: WebGPU.Device

    private var _label: String?
    
    var label: String? {
        get {
            _label
        }
        
        set {
            self.buffer.setLabel(newValue ?? "")
            self._label = newValue
        }
    }
    
    init(buffer: WebGPU.Buffer, device: WebGPU.Device) {
        self.buffer = buffer
        self.device = device
    }
    
    var length: Int { return Int(buffer.size) }
    
    func contents() -> UnsafeMutableRawPointer { 
        unsafe self.buffer.getMappedRange()
    }
    
    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        unsafe device.queue.writeBuffer(
            self.buffer, 
            bufferOffset: UInt64(offset), 
            data: UnsafeRawBufferPointer(start: bytes, count: byteCount)
        )
    }
}

#endif
