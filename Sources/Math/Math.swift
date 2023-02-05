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

@inline(__always)
public func clamp<T: Comparable>(_ value: T, _ min: T, _ max: T) -> T {
    return value < min ? (min) : (value > max ? max : value)
}

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

@inline(__always)
public func sin<T: FloatingPoint>(_ angle: T) -> T {
    if let double = angle as? Double {
#if os(Linux)
        return Glibc.sin(double) as! T
#else
        return Darwin.sin(double) as! T
#endif
        
    } else if let float = angle as? Float {
        return sinf(float) as! T
    }
    
    fatalError("Supports only float and double")
}

@inline(__always)
public func cos<T: FloatingPoint>(_ angle: T) -> T {
    if let double = angle as? Double {
#if os(Linux)
        return Glibc.cos(double) as! T
#else
        return Darwin.cos(double) as! T
#endif
        
    } else if let float = angle as? Float {
        return cosf(float) as! T
    }
    
    fatalError("Supports only float and double")
}

// swiftlint:enable identifier_name
