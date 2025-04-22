//
//  SparseArray.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/26/23.
//

/// Fast collection O(1) for insertion and deletion, but slow for resizing and iterating.
@frozen public struct SparseArray<Element> {
    
    public typealias Index = Int
    
    @usableFromInline
    internal var values: [Element?]
    
    @inline(__always)
    public init(capacity: Int) {
        self.values = [Element?].init(repeating: nil, count: capacity)
    }
    
    @inline(__always)
    public init<T: Sequence>(_ sequence: T) where T.Element == Element {
        self.values = [Element?].init(repeating: nil, count: sequence.underestimatedCount)
        
        for (index, element) in sequence.enumerated() {
            self.values[index] = element
        }
    }
}

extension SparseArray {
    
    @inline(__always)
    public subscript(_ index: Index) -> Element? {
        get {
            precondition(index < self.count, "Index out of range")
            return self.values[index]
        }
        
        mutating set {
            self.insert(newValue, at: index)
        }
    }
    
    /// Removes all keys and their associated values from the sparse set.
    ///
    /// - Parameter keepingCapacity: If `true` then the underlying storage's
    ///   capacity is preserved. The default is `false`.
    ///
    /// - Complexity: O(`count`)
    @inline(__always)
    public mutating func removeAll(keepingCapacity: Bool = false) {
        self.values.removeAll(keepingCapacity: keepingCapacity)
    }
    
    /// - Complexity: O(1)
    @inline(__always)
    @discardableResult
    public mutating func remove(at index: Index) -> Element? {
        let element = self.values[index]
        self.values[index] = nil
        return element
    }
    
    @inline(__always)
    @discardableResult
    public mutating func removeLast() -> Element? {
        return self.remove(at: self.count - 1)
    }
    
    @inline(__always)
    public mutating func insert(_ element: Element?, at index: Index) {
        if index >= self.count {
            values.reserveCapacity(index + 1)
            values.append(nil)
        }
        
        self.values[index] = element
    }
    
    @inline(__always)
    public mutating func append(_ element: Element) {
        self.insert(element, at: self.count)
    }
}

extension SparseArray: ExpressibleByArrayLiteral {
    @inline(__always)
    public init(arrayLiteral elements: Element...) {
        self = SparseArray(elements)
    }
}

extension SparseArray: Sequence {
    
    /// - Complexity: O(1)
    @inline(__always)
    public var underestimatedCount: Int {
        return self.values.underestimatedCount
    }
    
    /// - Complexity: O(1)
    @inline(__always)
    public var count: Int {
        return self.values.count
    }
    
    /// - Complexity: O(1)
    @inline(__always)
    public var isEmpty: Bool {
        return self.values.isEmpty
    }
    
    @inline(__always)
    public func makeIterator() -> Iterator {
        return Iterator(values: self.values)
    }
    
    @frozen
    public struct Iterator: IteratorProtocol {
        
        var pointer: Int = -1
        let values: [Element?]
        
        init(values: [Element?]) {
            self.values = values
        }
        
        public mutating func next() -> Element? {
            while true {
                self.pointer += 1
                
                if self.pointer >= self.values.count {
                    return nil
                }
                
                guard let item = self.values[self.pointer] else {
                    continue
                }
                
                return item
            }
        }
    }
}

extension SparseArray: Equatable where Element: Equatable {
    public static func == (lhs: SparseArray<Element>, rhs: SparseArray<Element>) -> Bool {
        return lhs.values == rhs.values
    }
}

extension SparseArray: Sendable where Element: Sendable { }

extension SparseArray: Hashable where Element: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.count)
        hasher.combine(self.values)
    }
}
