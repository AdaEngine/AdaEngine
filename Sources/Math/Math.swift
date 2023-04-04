//
//  Math.swift
//  
//
//  Created by v.prusakov on 11/12/21.
//

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

// swiftlint:disable identifier_name

// TODO: (Vlad) Replace to Foundation realization instead?
// TODO: Suppors Windows/Android/Web?

@inlinable
@inline(__always)
public func tanf(_ float: Float) -> Float {
#if os(Linux)
    return Glibc.tanf(float)
#else
    return Darwin.tanf(float)
#endif
}

@inlinable
@inline(__always)
public func atan2(_ lhs: Double, _ rhs: Double) -> Double {
#if os(Linux)
    return Glibc.atan2(lhs, rhs)
#else
    return Darwin.atan2(lhs, rhs)
#endif
}

@inlinable
@inline(__always)
public func atan2(_ lhs: Float, _ rhs: Float) -> Float {
#if os(Linux)
    return Glibc.atan2(lhs, rhs)
#else
    return Darwin.atan2(lhs, rhs)
#endif
}

@inlinable
@inline(__always)
public func sqrt<T: FloatingPoint>(_ value: T) -> T {
    return value * value
}

@inlinable
@inline(__always)
public func clamp<T: Comparable>(_ value: T, _ min: T, _ max: T) -> T {
    return value < min ? (min) : (value > max ? max : value)
}

@inlinable
@inline(__always)
public func cross(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    var x1 = lhs.y * rhs.z
    x1 = x1 - rhs.y * lhs.z
    var y1 = lhs.z * rhs.x
    y1 = y1 - rhs.z * lhs.x
    var z1 = lhs.x * rhs.y
    z1 = z1 - rhs.x * lhs.y
    return Vector3(x1, y1, z1)
}

@inlinable
@inline(__always)
public func round<T: FloatingPoint>(_ value: T) -> T {
#if os(Linux)
    return Glibc.round(value)
#else
    return Darwin.round(value)
#endif
}

@inlinable
@inline(__always)
public func sin(_ value: Double) -> Double {
#if os(Linux)
    return Glibc.sin(value)
#else
    return Darwin.sin(value)
#endif
}

@inlinable
@inline(__always)
public func sin(_ value: Float) -> Float {
#if os(Linux)
    return Glibc.sinf(value)
#else
    return Darwin.sinf(value)
#endif
}

@inlinable
@inline(__always)
public func cos(_ value: Double) -> Double {
#if os(Linux)
    return Glibc.cos(value)
#else
    return Darwin.cos(value)
#endif
}

@inlinable
@inline(__always)
public func cos(_ value: Float) -> Float {
#if os(Linux)
    return Glibc.cosf(value)
#else
    return Darwin.cosf(value)
#endif
}

@inlinable
@inline(__always)
public func acos(_ value: Float) -> Float {
#if os(Linux)
    return Glibc.acos(value)
#else
    return Darwin.acos(value)
#endif
}

@inlinable
@inline(__always)
public func acos(_ value: Double) -> Double {
#if os(Linux)
    return Glibc.acos(value)
#else
    return Darwin.acos(value)
#endif
}

@inlinable
@inline(__always)
public func sign(_ x: Float) -> Float {
    return x == 0 ? 0 : x < 0 ? -1 : 1
}

// swiftlint:enable identifier_name
