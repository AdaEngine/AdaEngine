//
//  UniqueHashable.swift
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
