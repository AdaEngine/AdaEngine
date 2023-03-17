//
//  Hashes.swift
//  
//
//  Created by v.prusakov on 3/17/23.
//

public protocol UniqueHashable: Equatable {
    
    associatedtype HasherFunction: UniqueHasher
    
    var uniqueHashValue: Int { get }
    
    func hash(into hasher: inout HasherFunction)
}

public extension UniqueHashable {
    var uniqueHashValue: Int {
        var hasher = HasherFunction()
        self.hash(into: &hasher)
        return hasher.finalize()
    }
}

public protocol UniqueHasher {
    
    init()

    /// Adds the given value to this hasher, mixing its essential parts into the
    /// hasher state.
    ///
    /// - Parameter value: A value to add to the hasher.
    mutating func combine<H>(_ value: H) where H : UniqueHashable

    /// Adds the contents of the given buffer to this hasher, mixing it into the
    /// hasher state.
    ///
    /// - Parameter bytes: A raw memory buffer.
    mutating func combine(bytes: UnsafeRawBufferPointer)

    /// Finalizes the hasher state and returns the hash value.
    ///
    /// Finalizing consumes the hasher: it is illegal to finalize a hasher you
    /// don't own, or to perform operations on a finalized hasher. (These may
    /// become compile-time errors in the future.)
    ///
    /// - Returns: The hash value calculated by the hasher.
    func finalize() -> Int
}

/// Calculate unique FNV Hash function
@frozen public struct FNVHasher: UniqueHasher {
    
    @usableFromInline
    var prime: Int = 16777619
    
    @usableFromInline
    var hash: Int = 2166136261
    
    public init() { }
    
    @inlinable
    public mutating func combine<H>(_ value: H) where H : UniqueHashable {
        self.hash ^= value.uniqueHashValue
        self.hash = hash & self.prime
    }
    
    public mutating func combine(bytes: UnsafeRawBufferPointer) {
        for index in 0..<bytes.count {
            self.hash ^= Int(bytes[index])
            self.hash = hash & self.prime
        }
    }
    
    public func finalize() -> Int {
        Int(truncatingIfNeeded: self.hash)
    }
}

extension String: UniqueHashable {
    public func hash(into hasher: inout FNVHasher) {
        self.utf8.withContiguousStorageIfAvailable { pointer in
            hasher.combine(bytes: UnsafeRawBufferPointer(pointer))
        }
    }
}

extension Int: UniqueHashable {
    public func hash(into hasher: inout FNVHasher) {
        CollectionOfOne(self).withContiguousStorageIfAvailable { pointer in
            hasher.combine(bytes: UnsafeRawBufferPointer(pointer))
        }
    }
}
