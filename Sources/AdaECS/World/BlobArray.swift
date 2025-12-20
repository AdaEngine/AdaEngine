//
//  BlobArray.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 10.06.2025.
//

import AdaUtils
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@safe
public struct BlobArray: Sendable {
    @unsafe
    final class _Buffer: @unchecked Sendable {
        let count: Int
        let pointer: UnsafeMutableRawBufferPointer
        var deinitializer: ((UnsafeMutableRawBufferPointer, Int) -> Void)?

        init(
            count: Int,
            pointer: UnsafeMutableRawBufferPointer,
            deinitializer: ((UnsafeMutableRawBufferPointer, Int) -> Void)? = nil
        ) {
            unsafe self.count = count
            unsafe self.pointer = pointer
            unsafe self.deinitializer = deinitializer
        }

        deinit {
            unsafe pointer.deallocate()
        }

        func clear(_ count: Int) {
            unsafe deinitializer?(pointer, count)
        }
    }

    public struct ElementLayout: Sendable {
        public let size: Int
        public let alignment: Int

        public init(size: Int, alignment: Int) {
            self.size = size
            self.alignment = alignment
        }
    }

    var buffer: _Buffer
    public let layout: ElementLayout
    public private(set) var count: Int
    let label: String?

    public init<T: ~Copyable>(
        count: Int,
        of type: T.Type,
        deinitializer: ((UnsafeMutableRawBufferPointer, Int) -> Void)? = nil
    ) {
        self.count = count
        self.layout = ElementLayout(size: MemoryLayout<T>.stride, alignment: MemoryLayout<T>.alignment)
        unsafe self.buffer = _Buffer(
            count: count,
            pointer: .allocate(
                byteCount: count * MemoryLayout<T>.stride,
                alignment: MemoryLayout<T>.alignment
            ),
            deinitializer: deinitializer
        )
        self.label = String(describing: T.self)
    }
}

public extension BlobArray {
    mutating func realloc(_ count: Int) {
        let newBuffer = unsafe _Buffer(
            count: count,
            pointer: .allocate(
                byteCount: count * self.layout.size,
                alignment: self.layout.alignment
            ),
            deinitializer: buffer.deinitializer
        )
        unsafe newBuffer.pointer.copyMemory(from: UnsafeRawBufferPointer(self.buffer.pointer))
        unsafe self.buffer = newBuffer
        self.count = count
    }

    func clear(_ count: Int) {
        unsafe self.buffer.clear(count)
    }

    func insert<T: ~Copyable>(_ element: consuming T, at index: Int) {
        #if DEBUG
        precondition(
            MemoryLayout<T>.stride == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
        #endif
        unsafe self.buffer.pointer
            .baseAddress!
            .advanced(by: index * self.layout.size)
            .assumingMemoryBound(to: T.self)
            .initialize(to: element)
    }

    func getMutablePointer<T: ~Copyable>(at index: Int, as type: T.Type) -> UnsafeMutablePointer<T> {
    #if DEBUG
        precondition(
            MemoryLayout<T>.stride == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
    #endif

        return unsafe self.buffer.pointer.baseAddress!
            .advanced(by: index * self.layout.size)
            .bindMemory(to: type, capacity: self.layout.size)
    }

    func get<T>(at index: Int, as type: T.Type) -> T {
    #if DEBUG
        precondition(
            MemoryLayout<T>.stride == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
    #endif
        return unsafe self.buffer.pointer.baseAddress!
            .advanced(by: index * self.layout.size)
            .bindMemory(to: type, capacity: self.layout.size)
            .pointee
    }

    func swapAndDrop(
        from fromIndex: Int,
        to toIndex: Int
    ) {
        precondition(fromIndex >= 0 && toIndex >= 0)
        precondition(layout.size >= 0)

        if fromIndex == toIndex || layout.size == 0 {
            return
        }
        let base = unsafe buffer.pointer.baseAddress!
        let fromPointer = unsafe base.advanced(by: fromIndex * layout.size)
        let toPointer: UnsafeMutableRawPointer = unsafe base.advanced(by: toIndex * layout.size)

        unsafe self.buffer.deinitializer?(UnsafeMutableRawBufferPointer(start: toPointer, count: 1), 1)
        unsafe withUnsafeTemporaryAllocation(of: UInt8.self, capacity: layout.size) { tmp in
            let tempPointer = UnsafeMutableRawPointer(tmp.baseAddress!)
            unsafe tempPointer.copyMemory(from: fromPointer, byteCount: layout.size)
            unsafe fromPointer.copyMemory(from: toPointer, byteCount: layout.size)
            unsafe toPointer.copyMemory(from: tempPointer, byteCount: layout.size)
        }
    }

    func remove<T>(at index: Int) -> T {
        #if DEBUG
        precondition(
            MemoryLayout<T>.stride == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
        #endif
        let pointer = unsafe self.buffer.pointer.baseAddress!
            .advanced(by: index * self.layout.size)
            .assumingMemoryBound(to: T.self)
        let element = unsafe pointer.pointee
        unsafe pointer.deinitialize(count: 1)
        return element
    }

    func copyElement(
        to blobArray: inout BlobArray,
        from fromIndex: Int,
        to toIndex: Int
    ) {
        #if DEBUG
        precondition(
            self.layout.size == blobArray.layout.size &&
            self.layout.alignment == blobArray.layout.alignment,
            "BlobArray has different layout"
        )
        #endif
        let sourcePointer = unsafe self.buffer.pointer.baseAddress!.advanced(by: fromIndex * self.layout.size)
        let destinationPointer = unsafe blobArray.buffer.pointer.baseAddress!.advanced(by: toIndex * self.layout.size)
        unsafe destinationPointer.copyMemory(from: sourcePointer, byteCount: self.layout.size)
    }
}
