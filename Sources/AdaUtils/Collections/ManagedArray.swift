//
//  ManagedArray.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.06.2025.
//

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
        var currentPointer: Int = -1
    }

    private var header: Header
    private var buffer: _Buffer

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return self.header.currentPointer + 1
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
        precondition(index >= 0 && index < self.header.capacity)
        self.buffer.pointer.initializeElement(at: index, to: element)
    }

    public mutating func append(_ element: consuming Element) {
        self.header.currentPointer += 1
//        print("Append element at index \(self.header.currentPointer)")
        if self.header.currentPointer > self.header.capacity - 1 {
//            print("Increase capacity \(self.header.capacity) -> \(self.header.capacity + 8)")
            increaseCapacity(to: self.header.capacity + 8)
        }
        self.header.count += 1
        self.insert(element, at: self.header.currentPointer)
    }

    public mutating func increaseCapacity(to capacity: Int) {
        precondition(self.header.capacity < capacity)
        let oldCount = self.header.capacity
        let newBuffer = _Buffer(pointer: .allocate(capacity: capacity), count: capacity)
        let _ = newBuffer.pointer.moveInitialize(fromContentsOf: self.buffer.pointer)
        self.header.capacity = capacity
        self.buffer = newBuffer
    }

    public func reborrow<U>(at index: Int, _ block: (inout Element) -> U) -> U {
        let pointer = buffer.pointer
            .baseAddress!
            .advanced(by: MemoryLayout<Element>.size * index)
        return block(&pointer.pointee)
    }

    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        print("Remove element at index \(index)")
        self.header.count -= 1
        let pointee = self.buffer.pointer.moveElement(from: index)
        return pointee
    }

    public func getPointer(at index: Int) -> UnsafeMutablePointer<Element> {
        self.buffer.pointer
            .baseAddress!
            .advanced(by: MemoryLayout<Element>.size * index)

    }

    public consuming func take(at index: Int) -> Element {
        self.buffer.pointer.moveElement(from: index)
    }

    public func forEach(_ body: (borrowing Element) -> Void) {
        for i in 0..<self.count {
            body(
                buffer.pointer
                .baseAddress!
                .advanced(by: MemoryLayout<Element>.size * i)
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
                .advanced(by: MemoryLayout<Element>.size * i)
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
