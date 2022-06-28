//
//  Buffer.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public class Buffer {
    
    public private(set) var contents: UnsafeMutableRawPointer
    public private(set) var length: Int
    
    init<T>(from data: [T]) {
        let length = MemoryLayout<T>.stride * data.count
        self.contents = UnsafeMutableRawPointer.allocate(byteCount: length, alignment: 0)
        self.contents.copyMemory(from: data, byteCount: length)
        self.length = length
    }
    
    init(byteCount: Int) {
        self.contents = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 0)
        self.length = byteCount
    }
    
    public func fillBuffer(_ bytes: UnsafeRawPointer, byteCount: Int, offset: Int) {
        self.contents.advanced(by: offset).copyMemory(from: bytes, byteCount: byteCount)
    }
    
    public func fillBuffer<T>(_ source: [T], offset: Int) {
        let byteCount = MemoryLayout<T>.stride * source.count
        self.contents.advanced(by: offset).copyMemory(from: source, byteCount: byteCount)
    }
    
    /// - Note: Resize the buffer if passed length more than length in buffer.
    public func updateBuffer(_ bytes: UnsafeRawPointer, length: Int) {
        if length > self.length {
            let newPointer = UnsafeMutableRawPointer.allocate(byteCount: length, alignment: 0)
            self.contents.deallocate()
            self.contents = newPointer
        }
        self.length = length
        self.contents.copyMemory(from: bytes, byteCount: length)
    }
    
    public func read<T>(as type: T.Type, offset: Int = 0) -> T {
        return self.contents.load(fromByteOffset: offset, as: type)
    }
    
    public func array<T>(of type: T.Type) -> [T] {
        let ptr = self.contents.bindMemory(to: T.self, capacity: self.length)
        return Array(UnsafeBufferPointer(start: ptr, count: self.length))
    }
    
    public func read<T>(offset: Int = 0) -> T {
        return self.contents.load(as: T.self)
    }
    
    deinit {
        self.contents.deallocate()
    }
    
}
