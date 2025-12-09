//
//  ManagedArray.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.06.2025.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct ManagedArray<Element>: @unchecked Sendable where Element: ~Copyable {

    struct Header {
        var capacity: Int
        var count: Int = 0
    }

    private var buffer: ManagedBuffer<Header, Element>

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        self.buffer.header.count
    }

    public var count: Int {
        self.buffer.header.count
    }

    public init() {
        self.buffer = ManagedBuffer<Header, Element>.create(
            minimumCapacity: 16,
            makingHeaderWith: { _ in
                Header(capacity: 16)
            }
        )
    }

    public init(count: Int) {
        precondition(count > 0)
        self.buffer = ManagedBuffer<Header, Element>.create(
            minimumCapacity: count * MemoryLayout<Element>.stride,
            makingHeaderWith: { _ in
                Header(capacity: count * MemoryLayout<Element>.stride, count: 0)
            }
        )
    }

//    public mutating func insert(_ element: consuming Element, at index: Int) {
//        precondition(index >= 0 && index <= self.buffer.header.count)
//        if buffer.header.count == buffer.header.capacity {
//            increaseCapacity(to: buffer.header.capacity > 0 ? buffer.header.capacity * 2 : 8)
//        }
//        self.buffer.withUnsafeMutablePointers { header, pointer in
//            header.pointee.count += 1
//            pointer.advanced(by: index * MemoryLayout<Element>.stride)
//                .initialize(to: element)
//        }
//    }

    public mutating func append(_ element: consuming Element) {
//         insert(element, at: buffer.header.count)
    }

    public mutating func increaseCapacity(to capacity: Int) {
        precondition(self.buffer.header.capacity < capacity)
        let oldBuffer = self.buffer
        self.buffer = ManagedBuffer<Header, Element>.create(
            minimumCapacity: capacity,
            makingHeaderWith: { _ in
                Header(capacity: capacity, count: oldBuffer.header.count)
            }
        )
        unsafe self.buffer.withUnsafeMutablePointers { (header, elements) in
            unsafe oldBuffer.withUnsafeMutablePointers { oldHeader, oldPtr in
                unsafe elements.moveUpdate(from: oldPtr, count: oldHeader.pointee.count)
            }
        }
    }

    @inline(__always)
    public func reborrow<U>(at index: Int, _ block: (inout Element) -> U) -> U {
        unsafe self.buffer.withUnsafeMutablePointerToElements { ptr in
            unsafe block(&ptr[index])
        }
    }

    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        precondition(index >= 0 && index < buffer.header.count)
        return unsafe buffer.withUnsafeMutablePointers { header, pointer in
            let nextToMove = unsafe header.pointee.count - index
            let place = unsafe pointer.advanced(by: index * MemoryLayout<Element>.stride)
            let value = unsafe place.move()
            let nextPtr = unsafe place.successor()
            unsafe place.moveUpdate(from: nextPtr, count: nextToMove)
            unsafe header.pointee.count -= 1
            return value
        }
//         if index < self.header.count - 1 {
//             baseAddress
//                 .advanced(by: MemoryLayout<Element>.stride * index)
//                 .moveInitialize(from: baseAddress.advanced(by: MemoryLayout<Element>.stride * index + 1), count: self.header.count - 1 - index)
//         }
    }

    public func getPointer(at index: Int) -> UnsafeMutablePointer<Element> {

        // self.buffer.pointer
        //     .baseAddress!
        //     .advanced(by: MemoryLayout<Element>.stride * index)
        fatalErrorMethodNotImplemented()
    }

    public consuming func take(at index: Int) -> Element {
        fatalErrorMethodNotImplemented()
//        precondition(index >= 0 && index < buffer.header.count)
//        return self.buffer.withUnsafeMutablePointerToElements { pointer in
//            pointer[index].move()
//        }
    }

    public func forEach(_ body: (borrowing Element) -> Void) {
        unsafe buffer.withUnsafeMutablePointers { header, pointer in
            for index in 0..<self.count {
                unsafe body(pointer[index])
            }
        }
    }

    public func map<T>(_ transform: (borrowing Element) -> T) -> [T] {
        var result: [T] = []
        result.reserveCapacity(self.count)
        unsafe buffer.withUnsafeMutablePointers { header, pointer in
            for index in 0..<self.count {
                unsafe result.append(transform(pointer[index]))
            }
        }
        return result
    }
}

extension ManagedArray: CustomStringConvertible where Element: NonCopybaleCustomStringConvertible {
    public var description: String {
        return """
        ManagedArray(
            count: \(self.count),
            capacity: \(self.buffer.header.capacity),
            elements: \(map { $0.description }.joined(separator: ", "))
        )
        """
    }
}

public protocol NonCopybaleCustomStringConvertible: ~Copyable {
    var description: String { get }
}
