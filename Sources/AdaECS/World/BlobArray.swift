//
//  BlobArray.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 10.06.2025.
//

import AdaUtils
import Foundation

public struct BlobArray: @unchecked Sendable {

    public struct ElementLayout {
        public let size: Int
        public let alignment: Int

        public init(size: Int, alignment: Int) {
            self.size = size
            self.alignment = alignment
        }
    }

    public var data: UnsafeMutableRawBufferPointer
    let layout: ElementLayout
    public private(set) var count: Int

    public init(count: Int, layout: ElementLayout) {
        self.data = UnsafeMutableRawBufferPointer.allocate(
            byteCount: count * layout.size,
            alignment: layout.alignment
        )
        self.layout = layout
        self.count = count
    }

    public init<T: ~Copyable>(count: Int, of type: T.Type) {
        self.count = count
        self.layout = ElementLayout(size: MemoryLayout<T>.size, alignment: MemoryLayout<T>.alignment)
        self.data = UnsafeMutableRawBufferPointer.allocate(
            byteCount: count * MemoryLayout<T>.size,
            alignment: MemoryLayout<T>.alignment
        )
    }
}

public extension BlobArray {

    func deallocate() {
        self.data.deallocate()
    }

    mutating func realloc(_ count: Int) {
        let newBuffer = UnsafeMutableRawBufferPointer.allocate(
            byteCount: count * self.layout.size,
            alignment: self.layout.alignment
        )
        newBuffer.copyMemory(from: UnsafeRawBufferPointer(self.data))
        self.data.deallocate()
        self.data = newBuffer
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
        self.data
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

        return self.data.baseAddress!
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
        return self.data.baseAddress!
            .advanced(by: index * self.layout.size)
            .bindMemory(to: type, capacity: self.layout.size)
            .pointee
    }

    func remove<T>(at index: Int) -> T {
        #if DEBUG
        precondition(
            MemoryLayout<T>.size == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
        #endif
        let pointer = self.data.baseAddress!
            .advanced(by: index * self.layout.size)
            .assumingMemoryBound(to: T.self)
        let element = pointer.pointee
        pointer.deinitialize(count: 1)
        return element
    }

    func copyElement(to blobArray: inout BlobArray, from fromIndex: Int, to toIndex: Int) {
        #if DEBUG
        precondition(
            self.layout.size == blobArray.layout.size &&
            self.layout.alignment == blobArray.layout.alignment,
            "BlobArray has different layout"
        )
        #endif
        let sourcePointer = self.data.baseAddress!.advanced(by: fromIndex * self.layout.size)
        let destinationPointer = blobArray.data.baseAddress!.advanced(by: toIndex * self.layout.size)
        destinationPointer.copyMemory(from: sourcePointer, byteCount: self.layout.size)
    }
}
