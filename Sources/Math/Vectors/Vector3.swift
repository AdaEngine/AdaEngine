//
//  Vector3.swift
//  
//
//  Created by v.prusakov on 6/22/22.
//

/// A 3-dimensional vector used for 3D math using floating point coordinates.
@frozen
public struct Vector3: Hashable, Equatable, Codable {
    public var x: Float
    public var y: Float
    public var z: Float
    
    @inlinable
    @inline(__always)
    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public extension Vector3 {
    @inlinable
    @inline(__always)
    init(_ scalar: Float) {
        self.x = scalar
        self.y = scalar
        self.z = scalar
    }
    
    @inlinable
    @inline(__always)
    init(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    @inlinable
    @inline(__always)
    init(_ xy: Float, _ z: Float) {
        self.x = xy
        self.y = xy
        self.z = z
    }
    
    @inlinable
    @inline(__always)
    init(_ vector2: Vector2, _ z: Float) {
        self.x = vector2.x
        self.y = vector2.y
        self.z = z
    }
}

public extension Vector3 {
    subscript(_ index: Int) -> Float {
        get {
            switch index {
            case 0:
                return x
            case 1:
                return y
            case 2:
                return z
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
            default: fatalError("Index out of range.")
            }
        }
    }
}

extension Vector3: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Float...) {
        assert(elements.count == 3)
        self.x = elements[0]
        self.y = elements[1]
        self.z = elements[2]
    }
}

extension Vector3 {
    public var description: String {
        return String(describing: type(of: self)) + "(\(x), \(y), \(z))"
    }
}

public extension Vector3 {
    @inlinable
    @inline(__always)
    static func * (lhs: Transform2D, rhs: Vector3) -> Vector3 {
        [
            lhs[0, 0] * rhs.x + lhs[1, 0] * rhs.y + lhs[2, 0] * rhs.z,
            lhs[0, 1] * rhs.x + lhs[1, 1] * rhs.y + lhs[2, 1] * rhs.z,
            lhs[0, 2] * rhs.x + lhs[1, 2] * rhs.y + lhs[2, 2] * rhs.z
        ]
    }
}

// MARK: Math Operations

public extension Vector3 {
    
    // MARK: Scalar
    
    @inlinable
    @inline(__always)
    static func * (lhs: Vector3, rhs: Float) -> Vector3 {
        return [lhs.x * rhs, lhs.y * rhs, lhs.z * rhs]
    }
    
    @inlinable
    @inline(__always)
    static func + (lhs: Vector3, rhs: Float) -> Vector3 {
        return [lhs.x + rhs, lhs.y + rhs, lhs.z + rhs]
    }
    
    @inlinable
    @inline(__always)
    static func - (lhs: Vector3, rhs: Float) -> Vector3 {
        return [lhs.x - rhs, lhs.y - rhs, lhs.z - rhs]
    }
    
    @inlinable
    @inline(__always)
    static func * (lhs: Float, rhs: Vector3) -> Vector3 {
        return [lhs * rhs.x, lhs * rhs.y, lhs * rhs.z]
    }
    
    @inlinable
    @inline(__always)
    static func + (lhs: Float, rhs: Vector3) -> Vector3 {
        return [lhs + rhs.x, lhs + rhs.y, lhs + rhs.z]
    }
    
    @inlinable
    @inline(__always)
    static func - (lhs: Float, rhs: Vector3) -> Vector3 {
        return [lhs - rhs.x, lhs - rhs.y, lhs - rhs.z]
    }
    
    @inlinable
    @inline(__always)
    static func / (lhs: Float, rhs: Vector3) -> Vector3 {
        return [lhs / rhs.x, lhs / rhs.y, lhs / rhs.z]
    }
    
    @inlinable
    @inline(__always)
    static func *= (lhs: inout Vector3, rhs: Float) {
        lhs = lhs * rhs
    }
    
    @inlinable
    @inline(__always)
    static func += (lhs: inout Vector3, rhs: Float) {
        lhs = lhs + rhs
    }
    
    @inlinable
    @inline(__always)
    static func -= (lhs: inout Vector3, rhs: Float) {
        lhs = lhs - rhs
    }
    
    @inlinable
    @inline(__always)
    static func /= (lhs: inout Vector3, rhs: Float) {
        lhs = lhs / rhs
    }
    
    // MARK: Vector
    
    @inlinable
    @inline(__always)
    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return [lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z]
    }
    
    @inlinable
    @inline(__always)
    static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return [lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z]
    }

    @inlinable
    @inline(__always)
    static func * (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return [lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z]
    }
    
    @inlinable
    @inline(__always)
    static func / (lhs: Vector3, rhs: Float) -> Vector3 {
        return [lhs.x / rhs, lhs.y / rhs, lhs.z / rhs]
    }
    
    @inlinable
    @inline(__always)
    static func / (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return [lhs.x / rhs.x, lhs.y / rhs.y, lhs.z / rhs.z]
    }
    
    @inlinable
    @inline(__always)
    static func *= (lhs: inout Vector3, rhs: Vector3) {
        lhs = lhs * rhs
    }
    
    @inlinable
    @inline(__always)
    static func += (lhs: inout Vector3, rhs: Vector3) {
        lhs = lhs + rhs
    }
    
    @inlinable
    @inline(__always)
    static func -= (lhs: inout Vector3, rhs: Vector3) {
        lhs = lhs - rhs
    }
    
    @inlinable
    @inline(__always)
    static func /= (lhs: inout Vector3, rhs: Vector3) {
        lhs = lhs / rhs
    }
}

public extension Vector3 {
    @inline(__always)
    static let zero: Vector3 = Vector3(0)
    
    @inline(__always)
    static let one: Vector3 = Vector3(1)
}

public extension Vector3 {
    var xy: Vector2 {
        get {
            return [x, y]
        }
        
        set {
            self.x = newValue.x
            self.y = newValue.y
        }
    }
}

public extension Vector3 {
    @inlinable
    @inline(__always)
    func cross(_ vec: Vector3) -> Vector3 {
        var x1 = self.y * vec.z
        x1 = x1 - vec.y * self.z
        var y1 = self.z * vec.x
        y1 = y1 - vec.z * self.x
        var z1 = self.x * vec.y
        z1 = z1 - vec.x * self.y
        
        return Vector3(x1, y1, z1)
    }
    
    @inlinable
    @inline(__always)
    var squaredLength: Float {
        return x * x + y * y + z * z
    }
    
    @inlinable
    @inline(__always)
    var length: Float {
        return sqrt(squaredLength)
    }
    
    @inlinable
    @inline(__always)
    var normalized: Vector3 {
        return self / self.length
    }
    
    @inlinable
    @inline(__always)
    func dot(_ vector: Vector3) -> Float {
        return x * vector.x + y * vector.y + z * vector.z
    }
    
    @inlinable
    @inline(__always)
    var isNaN: Bool {
        return self.x.isNaN || self.y.isNaN || self.z.isNaN
    }
    
    @inline(__always)
    static let up: Vector3 = Vector3(0, 1, 0)
    
    @inline(__always)
    static let down: Vector3 = Vector3(0, -1, 0)
    
    @inline(__always)
    static let left: Vector3 = Vector3(-1, 0, 0)
    
    @inline(__always)
    static let right: Vector3 = Vector3(1, 0, 0)
}

/// Returns a vector containing the minimum values for each element of `lhs` and `rhs`.
///
/// In other words this computes `[min(lhs.x, rhs.x), min(lhs.y, rhs.y), ..]`.
@inlinable
@inline(__always)
public func min(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    [
        min(lhs.x, rhs.x),
        min(lhs.y, rhs.y),
        min(lhs.z, rhs.z)
    ]
}

/// Returns a vector containing the maximum values for each element of `lhs` and `rhs`.
///
/// In other words this computes `[max(lhs.x, rhs.x), max(lhs.y, rhs.y), ..]`.
@inlinable
@inline(__always)
public func max(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    [
        max(lhs.x, rhs.x),
        max(lhs.y, rhs.y),
        max(lhs.z, rhs.z)
    ]
}
