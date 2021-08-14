//
//  Vector2.swift
//  
//
//  Created by v.prusakov on 8/12/21.
//

import Foundation
import simd

/// Vector with floats
public typealias Vector2 = Vector_2<Float>

protocol VectorScalar: Numeric, Hashable {
    
}


/// Base vector protocol
protocol Vector: Codable, Hashable {
    
}

public struct Vector_2<Scalar: VectorScalar>: Vector, Equatable {
    public var x: Scalar
    public var y: Scalar
}

public extension Vector_2: ExpressibleByArrayLiteral {
    
    /// Create
    init(arrayLiteral elements: ArrayLiteralElement...) {
        self.init(elements[0], elements[1])
    }
    
    init(_ x: Scalar, _ y: Scalar) {
        self.init(x: x, y: y)
    }
}

// MARK: - Methods

public extension Vector_2 where Scalar: FloatingPoint {
    
    static let zero = Vector_2(x: .zero, y: .zero)
    
    static let one = Vector_2(x: 1, y: 1)
    
}

// MARK: - Operators

public extension Vector_2 {
    static func * (lhs: Self, rhs: Self) -> Self {
        var newVector = lhs
        newVector.x = lhs.x * rhs.x
        newVector.y = lhs.y * rhs.x
        return newVector
    }
    
    static func *= (lhs: Scalar, rhs: Self) -> Self {
        var newVector = rhs
        newVector.x *= lhs
        newVector.y *= lhs
        return newVector
    }
}
