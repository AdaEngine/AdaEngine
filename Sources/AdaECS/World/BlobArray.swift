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
        var deallocator: (UnsafeMutableRawBufferPointer) -> Void

        init(
            pointer: UnsafeMutableRawBufferPointer,
            deallocator: @escaping (UnsafeMutableRawBufferPointer) -> Void
        ) {
            self.pointer = pointer
            self.deallocator = deallocator
        }

        deinit {
            deallocator(pointer)
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

    public init<T: ~Copyable>(count: Int, of type: T.Type) {
        self.count = count
        self.layout = ElementLayout(size: MemoryLayout<T>.size, alignment: MemoryLayout<T>.alignment)
        self.buffer = _Buffer(pointer: .allocate(
            byteCount: count * MemoryLayout<T>.size,
            alignment: MemoryLayout<T>.alignment
        ), deallocator: { ptr in
            print("Deinitize \(T.self)")
//            ptr.bindMemory(to: T.self).deinitialize()
        })
        self.label = String(describing: T.self)
    }
}

public extension BlobArray {
    mutating func realloc(_ count: Int) {
        let newBuffer = _Buffer(pointer: .allocate(
            byteCount: count * self.layout.size,
            alignment: self.layout.alignment
        ), deallocator: buffer.deallocator)
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
