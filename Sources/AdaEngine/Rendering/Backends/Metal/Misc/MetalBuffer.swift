//
//  MetalBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if METAL
@preconcurrency import Metal

class MetalBuffer: Buffer, @unchecked Sendable {
    let buffer: MTLBuffer
    
    var label: String? {
        get {
            self.buffer.label
        }
        
        set {
            self.buffer.label = newValue
        }
    }
    
    init(buffer: MTLBuffer) {
        self.buffer = buffer
    }
    
    var length: Int { return buffer.length }
    
    func contents() -> UnsafeMutableRawPointer { return self.buffer.contents() }
    
    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
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

        if self.contains(.storageManaged) {
            #if MACOS
            options.insert(.storageModeManaged)
            #else
            assertionFailure("ResourceOptions.storageManaged not available for iOS for Metal")
            options.insert(.storageModeShared)
            #endif
        }
        
        return options
    }
}

#endif
