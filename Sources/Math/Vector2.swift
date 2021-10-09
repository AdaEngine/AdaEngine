//
//  Vector2.swift
//  
//
//  Created by v.prusakov on 8/12/21.
//

import simd

/// Vector with floats
public typealias Vector2 = SIMD2<Float>
public typealias Vector2i = SIMD2<Int>
public typealias Vector3 = SIMD3<Float>

public protocol VectorScalar: Numeric, Hashable, Codable { }

extension Float: VectorScalar {}
extension Double: VectorScalar {}
extension Int: VectorScalar {}
extension UInt32: VectorScalar {}
extension UInt64: VectorScalar {}


/// Base vector protocol
public protocol Vector: Codable, Hashable {
    
}

public struct Vector_2<Scalar: VectorScalar>: Vector, Equatable {
    public var x: Scalar
    public var y: Scalar
    
    public init(_ x: Scalar, _ y: Scalar) {
        self.init(x: x, y: y)
    }
    
    public init(x: Scalar, y: Scalar) {
        self.x = x
        self.y = y
    }
}

extension Vector_2: ExpressibleByArrayLiteral where Scalar: FloatingPoint {
    
    /// Create
    public init(arrayLiteral elements: Scalar...) {
        self.init(elements[0], elements[1])
    }
    
}

// MARK: - Methods

public extension Vector_2 where Scalar == Float {
    
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


public struct _Vector3<Scalar: VectorScalar> {
    public var x: Scalar
    public var y: Scalar
    public var z: Scalar
    
    public init(_ x: Scalar, _ y: Scalar, _ z: Scalar) {
        self.init(x: x, y: y, z: z)
    }
    
    public init(x: Scalar, y: Scalar, z: Scalar) {
        self.x = x
        self.y = y
        self.z = z
    }
}

extension _Vector3: ExpressibleByArrayLiteral where Scalar: FloatingPoint {
    
    /// Create
    public init(arrayLiteral elements: Scalar...) {
        self.init(elements[0], elements[1], elements[2])
    }
    
}
