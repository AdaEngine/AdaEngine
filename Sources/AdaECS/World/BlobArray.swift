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
            .assumingMemoryBound(to: T.self)
            .initializeElement(at: index, to: element)

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
            .advanced(by: index * MemoryLayout<T>.stride)
            .assumingMemoryBound(to: T.self)
    }

    func get<T>(at index: Int, as type: T.Type) -> T {
    #if DEBUG
        precondition(
            MemoryLayout<T>.size == self.layout.size &&
            MemoryLayout<T>.alignment == self.layout.alignment,
            "Element has different layout"
        )
    #endif
        return self.data.load(fromByteOffset: index * MemoryLayout<T>.stride, as: type)
    }
}


