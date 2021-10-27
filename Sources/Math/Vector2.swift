//
//  Vector2.swift
//  
//
//  Created by v.prusakov on 8/12/21.
//

import simd

// TODO: Create object aka CGFloat for float or doubles
// TODO: when move to new vector object, we should use same object size

/// Vector with floats
public typealias Vector2 = SIMD2<Float>
public typealias Vector2i = SIMD2<Int>
public typealias Vector3 = SIMD3<Float>
public typealias Vector4 = SIMD4<Float>

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

public extension Vector_2 where Scalar == Double {
    
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

public extension Vector3 {
    func cross(_ vec: Vector3) -> Vector3 {
        var x1 = self.y * vec.z
        x1 = x1 - vec.y * self.z
        var y1 = self.z * vec.x
        y1 = y1 - vec.z * self.x
        var z1 = self.x * vec.y
        z1 = z1 - vec.x * self.y
        
        return Vector3(x1, y1, z1)
    }
    
    var squaredLength: Float {
        return x * x + y * y + z * z
    }
    
    var normalized: Vector3 {
        let length = self.squaredLength
        return self / sqrt(length)
    }
    
    func dot(_ vector: Vector3) -> Float {
        return x * vector.x + y * vector.y + z * vector.z
    }
    
    static let up: Vector3 = Vector3(0, 1, 0)
}

public extension Vector4 {
    
    var squaredLength: Float {
        return x * x + y * y + z * z + w * w
    }
    
    var normalized: Vector4 {
        let length = self.squaredLength
        return self / sqrt(length)
    }
    
    func dot(_ vector: Vector4) -> Float {
        return x * vector.x + y * vector.y + z * vector.z + w * vector.w
    }
}

extension Vector3 {
    public var description: String {
        return String(describing: type(of: self)) + "(\(x), \(y), \(z))"
    }
}

extension Vector4 {
    public var description: String {
        return String(describing: type(of: self)) + "(\(x), \(y), \(z), \(w))"
    }
}
