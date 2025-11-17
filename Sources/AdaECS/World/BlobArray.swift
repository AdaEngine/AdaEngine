//
//  BlobArray.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 10.06.2025.
//

import AdaUtils
import Foundation

public struct BlobArray: Sendable {
    final class _Buffer: @unchecked Sendable {
        let pointer: UnsafeMutableRawBufferPointer
        var deinitializer: ((UnsafeMutableRawBufferPointer) -> Void)?

        init(
            pointer: UnsafeMutableRawBufferPointer,
            deinitializer: ((UnsafeMutableRawBufferPointer) -> Void)? = nil
        ) {
            self.pointer = pointer
            self.deinitializer = deinitializer
        }

        deinit {
            deinitializer?(pointer)
            pointer.deallocate()
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
        deinitializer: ((UnsafeMutableRawBufferPointer) -> Void)? = nil
    ) {
        self.count = count
        self.layout = ElementLayout(size: MemoryLayout<T>.size, alignment: MemoryLayout<T>.alignment)
        self.buffer = _Buffer(
            pointer: .allocate(
                byteCount: count * MemoryLayout<T>.size,
                alignment: MemoryLayout<T>.alignment
            ),
            deinitializer: deinitializer
        )
        self.label = String(describing: T.self)
    }
}

public extension BlobArray {
    mutating func realloc(_ count: Int) {
        let newBuffer = _Buffer(
            pointer: .allocate(
                byteCount: count * self.layout.size,
                alignment: self.layout.alignment
            ),
            deinitializer: buffer.deinitializer
        )
        newBuffer.pointer.copyMemory(from: UnsafeRawBufferPointer(self.buffer.pointer))
        self.buffer = newBuffer
        self.count = count
    }

    func insert<T: ~Copyable>(_ element: consuming T, at index: Int) {
        #if DEBUG
        precondition(
            MemoryLayout<T>.size == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
        #endif
        self.buffer.pointer
            .baseAddress!
            .advanced(by: index * self.layout.size)
            .assumingMemoryBound(to: T.self)
            .initialize(to: element)
    }

    func getMutablePointer<T: ~Copyable>(at index: Int, as type: T.Type) -> UnsafeMutablePointer<T> {
    #if DEBUG
        precondition(
            MemoryLayout<T>.size == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
    #endif

        return self.buffer.pointer.baseAddress!
            .advanced(by: index * self.layout.size)
            .bindMemory(to: type, capacity: self.layout.size)
    }

    func get<T>(at index: Int, as type: T.Type) -> T {
    #if DEBUG
        precondition(
            MemoryLayout<T>.size == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
    #endif
        return self.buffer.pointer.baseAddress!
            .advanced(by: index * self.layout.size)
            .bindMemory(to: type, capacity: self.layout.size)
            .pointee
    }

    func swap(
        from fromIndex: Int,
        to toIndex: Int
    ) {
        precondition(fromIndex >= 0 && toIndex >= 0)
        precondition(layout.size >= 0)
        precondition(fromIndex + layout.size <= buffer.pointer.count)
        precondition(toIndex + layout.size <= buffer.pointer.count)

        if fromIndex == toIndex || layout.size == 0 {
            return
        }
        let base = buffer.pointer.baseAddress!
        let fromPointer = base.advanced(by: fromIndex * layout.size)
        let toPointer = base.advanced(by: toIndex * layout.size)

        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: layout.size) { tmp in
            let tempPointer = UnsafeMutableRawPointer(tmp.baseAddress!)
            tempPointer.copyMemory(from: fromPointer, byteCount: layout.size)
            fromPointer.copyMemory(from: toPointer, byteCount: layout.size)
            toPointer.copyMemory(from: tempPointer, byteCount: layout.size)
        }
    }

    func remove<T>(at index: Int) -> T {
        #if DEBUG
        print("Remove element for buffer \(self.label ?? "") at index: \(index)")
        precondition(
            MemoryLayout<T>.size == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
        #endif
        let pointer = self.buffer.pointer.baseAddress!
            .advanced(by: index * self.layout.size)
            .assumingMemoryBound(to: T.self)
        let element = pointer.pointee
        pointer.deinitialize(count: 1)
        return element
    }

    func copyElement(
        to blobArray: inout BlobArray,
        from fromIndex: Int,
        to toIndex: Int
    ) {
        #if DEBUG
        print("Copy element from buffer \(self.label ?? "") from index: \(fromIndex) to buffer \(blobArray.label ?? "") to index: \(toIndex)")
        precondition(
            self.layout.size == blobArray.layout.size &&
            self.layout.alignment == blobArray.layout.alignment,
            "BlobArray has different layout"
        )
        #endif
        let sourcePointer = self.buffer.pointer.baseAddress!.advanced(by: fromIndex * self.layout.size)
        let destinationPointer = blobArray.buffer.pointer.baseAddress!.advanced(by: toIndex * self.layout.size)
        destinationPointer.copyMemory(from: sourcePointer, byteCount: self.layout.size)
    }
}
