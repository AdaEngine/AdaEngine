//
//  RenderBuffer.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public class RenderBuffer {
    
    public private(set) var contents: UnsafeMutableRawPointer
    public private(set) var length: Int
    
    init(byteCount: Int) {
        self.contents = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 0)
        self.length = byteCount
    }
    
    public func fillBuffer(_ bytes: UnsafeRawPointer, byteCount: Int, offset: Int) {
        self.contents.advanced(by: offset).copyMemory(from: bytes, byteCount: byteCount)
    }
    
    public func fillBuffer<T>(_ source: [T], offset: Int) {
        let byteCount = MemoryLayout<T>.size * source.count
        self.contents.advanced(by: offset).copyMemory(from: source, byteCount: byteCount)
    }
    
    /// - Note: Resize the buffer if passed length more than length in buffer.
    public func updateBuffer(_ bytes: UnsafeRawPointer, length: Int) {
        if length > self.length {
            let newPointer = UnsafeMutableRawPointer.allocate(byteCount: length, alignment: 0)
            self.contents.deallocate()
            self.contents = newPointer
        }
        
        self.contents.copyMemory(from: bytes, byteCount: length)
    }
    
    deinit {
        self.contents.deallocate()
    }
    
}
