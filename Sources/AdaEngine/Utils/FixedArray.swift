//
//  FixedArray.swift
//  
//
//  Created by v.prusakov on 2/6/23.
//

/// Create a fixed sized array.
public struct FixedArray<T>: Sequence, RandomAccessCollection {
    
    public typealias Element = T?
    public typealias Index = Int
    
    private final class Buffer {
        let pointer: UnsafeMutableBufferPointer<Element>
        
        init(count: Int) {
            self.pointer = UnsafeMutableBufferPointer<Element>.allocate(capacity: count)
            self.pointer.initialize(repeating: nil)
        }
        
        deinit {
            pointer.deallocate()
        }
    }
    
    private let buffer: Buffer
    
    public init(count: Int) {
        // swiftlint:disable:next empty_count
        precondition(count > 0, "Can't allocate array with 0 elements.")
        self.buffer = Buffer(count: count)
    }
    
    public init(repeating: T, count: Int) {
        // swiftlint:disable:next empty_count
        precondition(count > 0, "Can't allocate array with 0 elements.")
        self.buffer = Buffer(count: count)
        self.buffer.pointer.assign(repeating: repeating)
    }
    
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
            
            self.buffer.pointer[index] = newValue
        }
    }
    
    // MARK: - Sequence
    
    public func makeIterator() -> UnsafeMutableBufferPointer<Element>.Iterator {
        return self.buffer.pointer.makeIterator()
    }
    
    // MARK: - Collection
    
    public var count: Int {
        return self.buffer.pointer.count
    }
    
    public var startIndex: Index {
        return self.buffer.pointer.startIndex
    }
    
    public var endIndex: Index {
        return self.buffer.pointer.endIndex
    }
    
    public func index(after i: Index) -> Index {
        return self.buffer.pointer.index(after: i)
    }
    
    /// Remove all elements and replace them by nil.
    public mutating func removeAll() {
        self.buffer.pointer.assign(repeating: nil)
    }
}

extension FixedArray: Equatable where T: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        
        for index in 0 ..< lhs.count {
            if lhs[index] != rhs[index] {
                return false
            }
        }
        
        return true
    }
}

extension FixedArray: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        let pointer = UnsafeRawBufferPointer(start: self.buffer.pointer.baseAddress, count: self.count)
        hasher.combine(bytes: pointer)
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
