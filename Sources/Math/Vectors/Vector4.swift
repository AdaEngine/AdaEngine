//
//  Vector4.swift
//  
//
//  Created by v.prusakov on 6/22/22.
//

import simd

public typealias Vector4 = SIMD4<Float>

extension Vector4 {
    public var description: String {
        return String(describing: type(of: self)) + "(\(x), \(y), \(z), \(w))"
    }
}

public extension Vector4 {
    static func * (lhs: Transform3D, rhs: Vector4) -> Vector4 {
        var rv = lhs.x * rhs.x
        rv = rv + lhs.y * rhs.y
        rv = rv + lhs.z * rhs.z
        rv = rv + lhs.w * rhs.w
        return rv
    }
    
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
