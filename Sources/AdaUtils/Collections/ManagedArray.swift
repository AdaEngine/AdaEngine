//
//  ManagedArray.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.06.2025.
//

import Foundation

public struct ManagedArray<Element>: @unchecked Sendable where Element: ~Copyable {

    final class _Buffer {
        let pointer: UnsafeMutableBufferPointer<Element>
        let count: Int

        init(pointer: UnsafeMutableBufferPointer<Element>, count: Int) {
            self.pointer = pointer
            self.count = count
        }

        deinit {
            pointer.deinitialize()
            pointer.deallocate()
        }
    }

    struct Header {
        var capacity: Int
        var count: Int = 0
    }

    private var header: Header
    private var buffer: _Buffer

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return self.header.count
    }

    public var count: Int {
        self.header.count
    }

    public init() {
        self.buffer = _Buffer(pointer: .allocate(capacity: 8), count: 8)
        self.header = Header(capacity: 8)
    }

    public init(count: Int) {
        precondition(count > 0)
        self.buffer = _Buffer(pointer: .allocate(capacity: count), count: 8)
        self.header = Header(capacity: count)
    }

    public mutating func insert(_ element: consuming Element, at index: Int) {
        precondition(index >= 0 && index <= self.header.count)
        if self.header.count == self.header.capacity {
            increaseCapacity(to: self.header.capacity > 0 ? self.header.capacity * 2 : 8)
        }
        let baseAddress = self.buffer.pointer.baseAddress!
        if index < self.header.count {
            baseAddress.advanced(by: MemoryLayout<Element>.stride * index + 1).moveInitialize(
                from: baseAddress.advanced(by: MemoryLayout<Element>.stride * index),
                count: self.header.count - index
            )
        }
        print(#function, "is main thread", Thread.isMainThread)
        print("initialize element at index \(index)")
        baseAddress.advanced(by: MemoryLayout<Element>.stride * index).initialize(to: element)
        self.header.count += 1
    }

    public mutating func append(_ element: consuming Element) {
        insert(element, at: self.header.count)
    }

    public mutating func increaseCapacity(to capacity: Int) {
        precondition(self.header.capacity < capacity)
        let newBuffer = _Buffer(pointer: .allocate(capacity: capacity), count: capacity)
        newBuffer.pointer.baseAddress!.moveInitialize(from: self.buffer.pointer.baseAddress!, count: self.header.count)
        self.header.capacity = capacity
        self.buffer = newBuffer
    }

    @inline(__always)
    public func reborrow<U>(at index: Int, _ block: (inout Element) -> U) -> U {
        let pointer = buffer.pointer
            .baseAddress!
            .advanced(by: MemoryLayout<Element>.stride * index)
        return block(&pointer.pointee)
    }

    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        precondition(index >= 0 && index < self.header.count)
        print("Remove chunk at index \(index)")
        let baseAddress = self.buffer.pointer.baseAddress!
        let element = baseAddress.advanced(by: MemoryLayout<Element>.stride * index).move()

        if index < self.header.count - 1 {
            baseAddress
                .advanced(by: MemoryLayout<Element>.stride * index)
                .moveInitialize(from: baseAddress.advanced(by: MemoryLayout<Element>.stride * index + 1), count: self.header.count - 1 - index)
        }
        
        self.header.count -= 1
        return element
    }

    public func getPointer(at index: Int) -> UnsafeMutablePointer<Element> {
        self.buffer.pointer
            .baseAddress!
            .advanced(by: MemoryLayout<Element>.stride * index)

    }

    public consuming func take(at index: Int) -> Element {
        precondition(index >= 0 && index < self.header.count)
        return (self.getPointer(at: index)).move()
    }

    public func forEach(_ body: (borrowing Element) -> Void) {
        for i in 0..<self.count {
            body(
                buffer.pointer
                .baseAddress!
                .advanced(by: MemoryLayout<Element>.stride * i)
                .pointee
            )
        }
    }

    public func map<T>(_ transform: (borrowing Element) -> T) -> [T] {
        var result: [T] = []
        result.reserveCapacity(self.count)
        for i in 0..<self.count {
            result.append(transform(
                buffer.pointer
                .baseAddress!
                .advanced(by: MemoryLayout<Element>.stride * i)
                .pointee
            ))
        }
        return result
    }
}

extension ManagedArray: CustomStringConvertible where Element: NonCopybaleCustomStringConvertible {
    public var description: String {
        return """
        ManagedArray(
            count: \(self.count),
            capacity: \(self.header.capacity),
            elements: \(map { $0.description }.joined(separator: ", "))
        )
        """
    }
}

public protocol NonCopybaleCustomStringConvertible: ~Copyable {
    var description: String { get }
}

class UnsafeBox<T: ~Copyable> {
    let value: T

    init(value: consuming T) {
        self.value = value
    }
}
