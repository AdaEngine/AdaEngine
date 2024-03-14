//
//  FixedArray.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/6/23.
//

// TODO: Replace to (repeat each T) with tuple

/// Create a fixed sized array on a heap.
@frozen
public struct FixedArray<T>: Sequence, RandomAccessCollection {
    
    public typealias Element = T?
    public typealias Index = Int
    
    @usableFromInline
    var buffer: Buffer
    
    @inline(__always)
    public init(count: Int) {
        // swiftlint:disable:next empty_count
        precondition(count > 0, "Can't allocate array with 0 elements.")
        self.buffer = Buffer(count: count)
    }
    
    @inline(__always)
    public init(repeating: T, count: Int) {
        // swiftlint:disable:next empty_count
        precondition(count > 0, "Can't allocate array with 0 elements.")
        self.buffer = Buffer(count: count)
        self.buffer.pointer.update(repeating: repeating)
    }
    
    @inline(__always)
    public subscript(index: Index) -> Element {
        get {
            if index < self.startIndex || index >= self.endIndex {
                fatalError("Index out of range")
            }
            
            return self.buffer.pointer[index]
        }
        
        set {
            if index < self.startIndex || index >= self.endIndex {
                fatalError("Index out of range")
            }
            
            self._ensureUnique()
            
            self.buffer.pointer[index] = newValue
        }
    }
    
    // MARK: - Sequence
    
    @inline(__always)
    public func makeIterator() -> UnsafeMutableBufferPointer<Element>.Iterator {
        return self.buffer.pointer.makeIterator()
    }
    
    // MARK: - Collection
    
    @inline(__always)
    public var count: Int {
        return self.buffer.pointer.count
    }
    
    @inline(__always)
    public var startIndex: Index {
        return self.buffer.pointer.startIndex
    }
    
    @inline(__always)
    public var endIndex: Index {
        return self.buffer.pointer.endIndex
    }
    
    @inline(__always)
    public func index(after i: Index) -> Index {
        return self.buffer.pointer.index(after: i)
    }
    
    /// Remove all elements and replace them by nil.
    @inline(__always)
    public mutating func removeAll() {
        self._ensureUnique()
        self.buffer.pointer.update(repeating: nil)
    }
    
    /// Ensures that the sparse data storage buffer is uniquely referenced,
    /// copying it if necessary.
    ///
    /// This function should be called whenever key data is mutated in a way that
    /// would make the sparse storage inconsistent with the keys in the dense
    /// storage.
    @usableFromInline
    internal mutating func _ensureUnique() {
        if !isKnownUniquelyReferenced(&buffer) {
            self.buffer = Buffer.buffer(count: self.count, contentsOf: buffer)
        }
    }
}

extension FixedArray: Equatable where T: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        
        return lhs.buffer.pointer.elementsEqual(rhs.buffer.pointer)
    }
}

extension FixedArray: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.count)
        for element in self {
            hasher.combine(element)
        }
    }
}

extension FixedArray: CustomStringConvertible {
    public var description: String {
        let values: [String] = self.map {
            guard let value = $0 else {
                return "nil"
            }
            
            return String(describing: value)
        }
        
        return "FixedArray<\(T.self), \(self.count)> [\(values.joined(separator: ", "))]"
    }
}

// MARK: - Codable

extension FixedArray: Encodable where T: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.count, forKey: .length)
        
        let values = Array(self.buffer.pointer)
        try container.encode(values, forKey: .values)
    }
}

extension FixedArray: Decodable where T: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let length = try container.decode(Int.self, forKey: .length)
        let values = try container.decode([T?].self, forKey: .values)
        self.buffer = Buffer(count: length)
        
        for (index, value) in values.enumerated() {
            self.buffer.pointer[index] = value
        }
    }
}

extension FixedArray {
    enum CodingKeys: CodingKey {
        case length
        case values
    }
}

extension FixedArray {
    @usableFromInline
    internal final class Buffer {
        let pointer: UnsafeMutableBufferPointer<Element>
        
        init(count: Int) {
            self.pointer = UnsafeMutableBufferPointer<Element>.allocate(capacity: count)
            self.pointer.initialize(repeating: nil)
        }
        
        func moveMemory(to destination: UnsafeMutableBufferPointer<Element>) {
            self.pointer.baseAddress?.moveUpdate(from: destination.baseAddress!, count: self.pointer.count)
        }
        
        deinit {
            pointer.deallocate()
        }
        
        static func buffer(count: Int, contentsOf buffer: Buffer) -> Buffer {
            let newBuffer = Buffer(count: count)
            buffer.moveMemory(to: newBuffer.pointer)
            return newBuffer
        }
    }
}
