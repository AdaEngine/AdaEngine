//
//  MetalBuffer.swift
//  
//
//  Created by v.prusakov on 1/18/23.
//

#if METAL
import Metal

public class MetalBuffer: Buffer {
    let buffer: MTLBuffer
    
    init(buffer: MTLBuffer) {
        self.buffer = buffer
    }
    
    public var length: Int { return buffer.length }
    
    public func contents() -> UnsafeMutableRawPointer { return self.buffer.contents() }
    
    public func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        self.buffer.contents().advanced(by: offset).copyMemory(from: bytes, byteCount: byteCount)
    }
}

extension ResourceOptions {
    var metal: MTLResourceOptions {
        
        var options: MTLResourceOptions = []
        
        if self.contains(.storagePrivate) {
            options.insert(.storageModePrivate)
        }
        
        if self.contains(.storageShared) {
            options.insert(.storageModeShared)
        }
        
        return options
    }
}

#endif
