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
    
    init(buffer: WebGPU.Buffer) {
        self.buffer = buffer
    }
    
    var length: Int { return Int(buffer.size) }
    
    func contents() -> UnsafeMutableRawPointer { 
        unsafe self.buffer.getMappedRange()
    }
    
    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        let result = unsafe self.buffer.writeMappedRange(offset: offset, data: UnsafeRawBufferPointer(start: bytes, count: byteCount))
        assert(result == .success)
    }
}

#endif
