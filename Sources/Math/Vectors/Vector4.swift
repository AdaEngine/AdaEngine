//
//  Vector4.swift
//  
//
//  Created by v.prusakov on 6/22/22.
//

import Foundation

public struct Vector4: Hashable, Equatable, Codable {
    public var x: Float
    public var y: Float
    public var z: Float
    public var w: Float

    @inline(__always)
    public init(x: Float, y: Float, z: Float, w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
}

public extension Vector4 {
    @inline(__always)
    init(_ scalar: Float) {
        self.x = scalar
        self.y = scalar
        self.z = scalar
        self.w = scalar
    }
    
    @inline(__always)
    init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    
    @inline(__always)
    init(_ xyz: Float, _ w: Float) {
        self.x = xyz
        self.y = xyz
        self.z = xyz
        self.w = w
    }
    
    @inline(__always)
    init(_ vector3: Vector3, _ w: Float) {
        self.x = vector3.x
        self.y = vector3.y
        self.z = vector3.z
        self.w = w
    }
}

extension Vector4: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Float...) {
        assert(elements.count == 4)
        self.x = elements[0]
        self.y = elements[1]
        self.z = elements[2]
        self.w = elements[3]
    }
}

public extension Vector4 {
    subscript(_ index: Int) -> Float {
        get {
            switch index {
            case 0:
                return x
            case 1:
                return y
            case 2:
                return z
            case 3:
                return w
            default:
                fatalError("Index out of range.")
            }
        }
        
        set {
            switch index {
            case 0:
                self.x = newValue
            case 1:
                self.y = newValue
            case 2:
                self.z = newValue
            case 3:
                self.w = newValue
            default: fatalError("Index out of range.")
            }
        }
    }
}

extension Vector4 {
    public var description: String {
        return String(describing: type(of: self)) + "(\(x), \(y), \(z), \(w))"
    }
}

// MARK: Math Operations

public extension Vector4 {
    
    // MARK: Scalar
    
    @inline(__always)
    static func * (lhs: Vector4, rhs: Float) -> Vector4 {
        return [lhs.x * rhs, lhs.y * rhs, lhs.z * rhs, lhs.w * rhs]
    }
    
    @inline(__always)
    static func + (lhs: Vector4, rhs: Float) -> Vector4 {
        return [lhs.x + rhs, lhs.y + rhs, lhs.z + rhs, lhs.w + rhs]
    }
    
    @inline(__always)
    static func - (lhs: Vector4, rhs: Float) -> Vector4 {
        return [lhs.x - rhs, lhs.y - rhs, lhs.z - rhs, lhs.w - rhs]
    }
    
    @inline(__always)
    static func * (lhs: Float, rhs: Vector4) -> Vector4 {
        return [lhs * rhs.x, lhs * rhs.y, lhs * rhs.z, lhs * rhs.w]
    }
    
    @inline(__always)
    static func + (lhs: Float, rhs: Vector4) -> Vector4 {
        return [lhs + rhs.x, lhs + rhs.y, lhs + rhs.z, lhs + rhs.w]
    }
    
    @inline(__always)
    static func - (lhs: Float, rhs: Vector4) -> Vector4 {
        return [lhs - rhs.x, lhs - rhs.y, lhs - rhs.z, lhs - rhs.w]
    }
    
    @inline(__always)
    static func / (lhs: Float, rhs: Vector4) -> Vector4 {
        return [lhs / rhs.x, lhs / rhs.y, lhs / rhs.z, lhs / rhs.w]
    }
    
    @inline(__always)
    static func *= (lhs: inout Vector4, rhs: Float) {
        lhs = lhs * rhs
    }
    
    @inline(__always)
    static func -= (lhs: inout Vector4, rhs: Float) {
        lhs = lhs - rhs
    }
    
    @inline(__always)
    static func /= (lhs: inout Vector4, rhs: Float) {
        lhs = lhs / rhs
    }
    
    @inline(__always)
    static func += (lhs: inout Vector4, rhs: Float) {
        lhs = lhs + rhs
    }
    
    @inline(__always)
    static func / (lhs: Vector4, rhs: Float) -> Vector4 {
        return [lhs.x / rhs, lhs.y / rhs, lhs.z / rhs, lhs.w / rhs]
    }
    
    @inline(__always)
    static func - (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return [lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z, lhs.w - rhs.w]
    }
    
    @inline(__always)
    static func + (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return [lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z, lhs.w + rhs.w]
    }
    
    @inline(__always)
    static func * (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return [lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z, lhs.w * rhs.w]
    }
    
    // MARK: Vector
    
    @inline(__always)
    static func / (lhs: Vector4, rhs: Vector4) -> Vector4 {
        return [lhs.x / rhs.x, lhs.y / rhs.y, lhs.z / rhs.z, lhs.w / rhs.w]
    }
    
    @inline(__always)
    static func *= (lhs: inout Vector4, rhs: Vector4) {
        lhs = lhs * rhs
    }
    
    @inline(__always)
    static func += (lhs: inout Vector4, rhs: Vector4) {
        lhs = lhs + rhs
    }
    
    @inline(__always)
    static func -= (lhs: inout Vector4, rhs: Vector4) {
        lhs = lhs - rhs
    }
    
    @inline(__always)
    static func /= (lhs: inout Vector4, rhs: Vector4) {
        lhs = lhs / rhs
    }
    
    // MARK: Matrix
    
    @inline(__always)
    static func * (lhs: Transform3D, rhs: Vector4) -> Vector4 {
        var rv = lhs.x * rhs.x
        rv = rv + lhs.y * rhs.y
        rv = rv + lhs.z * rhs.z
        rv = rv + lhs.w * rhs.w
        return rv
    }
    
    @inline(__always)
    static func * (lhs: Vector4, rhs: Transform3D) -> Vector4 {
        var x = lhs.x * rhs.x.x
        x = x + lhs.y * rhs.x.y
        x = x + lhs.z * rhs.x.z
        x = x + lhs.w * rhs.x.w
        var y = lhs.x * rhs.y.x
        y = y + lhs.y * rhs.y.y
        y = y + lhs.z * rhs.y.z
        y = y + lhs.w * rhs.y.w
        var z = lhs.x * rhs.z.x
        z = z + lhs.y * rhs.z.y
        z = z + lhs.z * rhs.z.z
        z = z + lhs.w * rhs.z.w
        var w = lhs.x * rhs.w.x
        w = w + lhs.y * rhs.w.y
        w = w + lhs.z * rhs.w.z
        w = w + lhs.w * rhs.w.w
        return Vector4(x, y, z, w)
    }
}

public extension Vector4 {
    @inline(__always)
    static let zero: Vector4 = Vector4(0)
    
    @inline(__always)
    static let one: Vector4 = Vector4(1)
}

public extension Vector4 {
    @inline(__always)
    var squaredLength: Float {
        return x * x + y * y + z * z + w * w
    }
    
    @inline(__always)
    var normalized: Vector4 {
        let length = self.squaredLength
        return self / sqrt(length)
    }
    
    @inline(__always)
    func dot(_ vector: Vector4) -> Float {
        return x * vector.x + y * vector.y + z * vector.z + w * vector.w
    }
}
