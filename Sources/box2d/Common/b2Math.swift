/**
 Copyright (c) 2006-2014 Erin Catto http://www.box2d.org
 Copyright (c) 2015 - Yohei Yoshihara
 
 This software is provided 'as-is', without any express or implied
 warranty.  In no event will the authors be held liable for any damages
 arising from the use of this software.
 
 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:
 
 1. The origin of this software must not be misrepresented; you must not
 claim that you wrote the original software. If you use this software
 in a product, an acknowledgment in the product documentation would be
 appreciated but is not required.
 
 2. Altered source versions must be plainly marked as such, and must not be
 misrepresented as being the original software.
 
 3. This notice may not be removed or altered from any source distribution.
 
 This version of box2d was developed by Yohei Yoshihara. It is based upon
 the original C++ code written by Erin Catto.
 */

import Foundation

public typealias b2Float = Float32

/**
 This function is used to ensure that a floating point number is not a NaN or infinity.
 */
func b2IsValid(_ x: b2Float) -> Bool {
    return x.isNaN == false && x.isInfinite == false
}

/**
 This is a approximate yet fast inverse square-root.
 TODO: implement actual fast inverse square-root
 */
func b2InvSqrt(_ x: b2Float) -> b2Float {
    return 1.0 / sqrt(x)
}

func b2Sqrt(_ x: b2Float) -> b2Float {
    return sqrt(x)
}

func b2Atan2(_ y: b2Float, _ x: b2Float) -> b2Float {
    return atan2(y, x)
}

/**
 A 2D column vector.
 */
public struct b2Vec2 : Equatable, CustomStringConvertible {
    /**
     Default constructor does nothing (for performance).
     */
    public init() {
        x = 0
        y = 0
    }
    /**
     Construct using coordinates.
     */
    public init(_ x_ : b2Float, _ y_ : b2Float) {
        x = x_
        y = y_
    }
    /**
     Set this vector to all zeros.
     */
    public mutating func setZero() {
        x = 0.0
        y = 0.0
    }
    /**
     Set this vector to some specified coordinates.
     */
    public mutating func set(_ x_ : b2Float, _ y_ : b2Float) {
        x = x_
        y = y_
    }
    public subscript(index: Int) -> b2Float {
        /**
         Read from and indexed element.
         */
        get {
            assert(0 <= index && index <= 1)
            if index == 0 {
                return x
            }
            else {
                return y
            }
        }
        /**
         Write to an indexed element.
         */
        set(newValue) {
            assert(0 <= index && index <= 1)
            if index == 0 {
                x = newValue
            }
            else {
                y = newValue
            }
        }
    }
    /**
     Get the length of this vector (the norm).
     */
    public func length() -> b2Float {
        return sqrt(x * x + y * y)
    }
    /**
     Get the length squared. For performance, use this instead of
     b2Vec2::Length (if possible).
     */
    public func lengthSquared() -> b2Float {
        return x * x + y * y
    }
    /**
     Convert this vector into a unit vector. Returns the length.
     */
    @discardableResult public mutating func normalize() -> b2Float {
        let length = self.length()
        if length < b2_epsilon {
            return 0.0
        }
        let invLength = 1.0 / length
        x *= invLength
        y *= invLength
        
        return length
    }
    /**
     Does this vector contain finite coordinates?
     */
    public func isValid() -> Bool {
        return b2IsValid(x) && b2IsValid(y)
    }
    /**
     Get the skew vector such that dot(skew_vec, other) == cross(vec, other)
     */
    public func skew() -> b2Vec2 {
        return b2Vec2(-y, x)
    }
    
    public var description: String {
        get {
            return "(\(x),\(y))"
        }
    }
    
    public var x: b2Float
    public var y: b2Float
}

/*
 Negate this vector.
 */
public prefix func - (v: b2Vec2) -> b2Vec2 {
    let _v = b2Vec2(-v.x, -v.y)
    return _v
}

/**
 Add a vector to this vector.
 */
public func += (a: inout b2Vec2, b: b2Vec2) {
    a.x += b.x
    a.y += b.y
}

/**
 Subtract a vector from this vector.
 */
public func -= (a: inout b2Vec2, b: b2Vec2) {
    a.x -= b.x
    a.y -= b.y
}

/**
 Multiply this vector by a scalar.
 */
public func *= (a: inout b2Vec2, b: b2Vec2) {
    a.x *= b.x
    a.y *= b.y
}

/**
 Multiply this vector by a scalar.
 */
public func *= (a: inout b2Vec2, b: b2Float) {
    a.x *= b
    a.y *= b
}

/**
 A 2D column vector with 3 elements.
 */
public struct b2Vec3 : CustomStringConvertible {
    /**
     Default constructor does nothing (for performance).
     */
    init() {
        x = 0.0
        y = 0.0
        z = 0.0
    }
    /**
     Construct using coordinates.
     */
    init(_ x_ : b2Float, _ y_ : b2Float, _ z_ : b2Float) {
        x = x_
        y = y_
        z = z_
    }
    /**
     Set this vector to all zeros.
     */
    mutating func setZero() {
        x = 0.0
        y = 0.0
    }
    /**
     Set this vector to some specified coordinates.
     */
    mutating func set(_ x_: b2Float, _ y_: b2Float, _ z_: b2Float) {
        x = x_
        y = y_
        z = z_
    }
    
    public var description: String {
        get {
            return "(\(x),\(y),\(z))"
        }
    }
    
    var x : b2Float
    var y : b2Float
    var z : b2Float
}

/**
 Negate this vector.
 */
public prefix func - (v: b2Vec3) -> b2Vec3 {
    let _v = b2Vec3(-v.x, -v.y, -v.z)
    return _v
}
/**
 Add a vector to this vector.
 */
public func += (a: inout b2Vec3, b: b2Vec3) {
    a.x += b.x
    a.y += b.y
    a.z += b.z
}
/**
 Subtract a vector from this vector.
 */
public func -= (a: inout b2Vec3, b: b2Vec3) {
    a.x -= b.x
    a.y -= b.y
    a.z -= b.z
}
/**
 Multiply this vector by a vecto.
 */
public func *= (a: inout b2Vec3, b: b2Vec3) {
    a.x *= b.x
    a.y *= b.y
    a.z *= b.z
}

/**
 Multiply this vector by a scalar.
 */
public func *= (a: inout b2Vec3, b: b2Float) {
    a.x *= b
    a.y *= b
    a.z *= b
}

/**
 A 2-by-2 matrix. Stored in column-major order.
 */
public struct b2Mat22 : CustomStringConvertible {
    /**
     The default constructor does nothing (for performance).
     */
    public init() {
        ex = b2Vec2(0.0, 0.0)
        ey = b2Vec2(0.0, 0.0)
    }
    /**
     Construct this matrix using columns.
     */
    public init(_ c1: b2Vec2, _ c2: b2Vec2) {
        ex = c1
        ey = c2
    }
    /**
     Construct this matrix using scalars.
     */
    public init(_ a11: b2Float, _ a12: b2Float, _ a21: b2Float, _ a22: b2Float) {
        ex = b2Vec2(a11, a12)
        ey = b2Vec2(a21, a22)
    }
    /**
     Initialize this matrix using columns.
     */
    public mutating func set(_ c1: b2Vec2, _ c2: b2Vec2) {
        ex = c1
        ey = c2
    }
    /**
     Set this to the identity matrix.
     */
    public mutating func setIdentity() {
        ex.x = 1.0; ey.x = 0.0
        ex.y = 0.0; ey.y = 1.0
    }
    /**
     Set this matrix to all zeros.
     */
    public mutating func setZero() {
        ex.x = 0.0; ey.x = 0.0
        ex.y = 0.0; ey.y = 0.0
    }
    
    public func getInverse() -> b2Mat22 {
        let a = ex.x, b = ey.x, c = ex.y, d = ey.y
        var B = b2Mat22()
        var det = a * d - b * c
        if det != 0.0 {
            det = 1.0 / det
        }
        B.ex.x =  det * d;  B.ey.x = -det * b
        B.ex.y = -det * c;  B.ey.y =  det * a
        return B
    }
    /**
     Solve A * x = b, where b is a column vector. This is more efficient
     than computing the inverse in one-shot cases.
     */
    public func solve(_ b: b2Vec2) -> b2Vec2 {
        let a11 = ex.x, a12 = ey.x, a21 = ex.y, a22 = ey.y
        var det = a11 * a22 - a12 * a21
        if det != 0.0 {
            det = 1.0 / det
        }
        var x = b2Vec2()
        x.x = det * (a22 * b.x - a12 * b.y)
        x.y = det * (a11 * b.y - a21 * b.x)
        return x
    }
    
    public var description: String {
        get {
            return "(\(ex),\(ey))"
        }
    }
    
    public var ex : b2Vec2
    public var ey : b2Vec2
}

/**
 A 3-by-3 matrix. Stored in column-major order.
 */
public struct b2Mat33 : CustomStringConvertible {
    /**
     The default constructor does nothing (for performance).
     */
    public init() {
        ex = b2Vec3()
        ey = b2Vec3()
        ez = b2Vec3()
    }
    /**
     Construct this matrix using columns.
     */
    public init(_ c1: b2Vec3, _ c2: b2Vec3, _ c3: b2Vec3) {
        ex = c1
        ey = c2
        ez = c3
    }
    /**
     Set this matrix to all zeros.
     */
    public mutating func setZero() {
        ex.setZero()
        ey.setZero()
        ez.setZero()
    }
    
    /**
     Solve A * x = b, where b is a column vector. This is more efficient
     than computing the inverse in one-shot cases.
     */
    public func solve33(_ b: b2Vec3) -> b2Vec3 {
        var det = b2Dot(ex, b2Cross(ey, ez))
        if det != 0.0 {
            det = 1.0 / det
        }
        var x = b2Vec3()
        x.x = det * b2Dot(b, b2Cross(ey, ez))
        x.y = det * b2Dot(ex, b2Cross(b, ez))
        x.z = det * b2Dot(ex, b2Cross(ey, b))
        return x
    }
    
    /**
     Solve A * x = b, where b is a column vector. This is more efficient
     than computing the inverse in one-shot cases.
     */
    public func solve22(_ b: b2Vec2) -> b2Vec2 {
        let a11 = ex.x, a12 = ey.x, a21 = ex.y, a22 = ey.y
        var det = a11 * a22 - a12 * a21
        if det != 0.0 {
            det = 1.0 / det
        }
        var x = b2Vec2()
        x.x = det * (a22 * b.x - a12 * b.y)
        x.y = det * (a11 * b.y - a21 * b.x)
        return x
    }
    /**
     Get the inverse of this matrix as a 2-by-2.
     Returns the zero matrix if singular.
     */
    public func getInverse22() -> b2Mat33 {
        let a = ex.x, b = ey.x, c = ex.y, d = ey.y
        var det = a * d - b * c
        if det != 0.0 {
            det = 1.0 / det
        }
        
        var M = b2Mat33()
        M.ex.x =  det * d;	M.ey.x = -det * b; M.ex.z = 0.0
        M.ex.y = -det * c;	M.ey.y =  det * a; M.ey.z = 0.0
        M.ez.x = 0.0; M.ez.y = 0.0; M.ez.z = 0.0
        return M
    }
    /**
     Get the symmetric inverse of this matrix as a 3-by-3.
     Returns the zero matrix if singular.
     */
    public func getSymInverse33() -> b2Mat33 {
        var det = b2Dot(ex, b2Cross(ey, ez))
        if det != 0.0 {
            det = 1.0 / det
        }
        
        let a11 = ex.x, a12 = ey.x, a13 = ez.x
        let a22 = ey.y, a23 = ez.y
        let a33 = ez.z
        
        var M = b2Mat33()
        M.ex.x = det * (a22 * a33 - a23 * a23)
        M.ex.y = det * (a13 * a23 - a12 * a33)
        M.ex.z = det * (a12 * a23 - a13 * a22)
        
        M.ey.x = M.ex.y
        M.ey.y = det * (a11 * a33 - a13 * a13)
        M.ey.z = det * (a13 * a12 - a11 * a23)
        
        M.ez.x = M.ex.z
        M.ez.y = M.ey.z
        M.ez.z = det * (a11 * a22 - a12 * a12)
        return M
    }
    public var description: String {
        get {
            return "(\(ex),\(ey),\(ez))"
        }
    }
    
    public var ex : b2Vec3
    public var ey : b2Vec3
    public var ez : b2Vec3
}

/**
 Rotation
 */
public struct b2Rot : CustomStringConvertible {
    public init() {
        s = 0.0
        c = 0.0
    }
    
    /**
     Initialize from an angle in radians
     */
    public init(_ angle : b2Float) {
        s = sin(angle)
        c = cos(angle)
    }
    /**
     Set using an angle in radians.
     */
    public mutating func set(_ angle : b2Float) {
        s = sin(angle)
        c = cos(angle)
    }
    /**
     Set to the identity rotation
     */
    public mutating func setIdentity() {
        s = 0.0
        c = 1.0
    }
    /**
     Get the angle in radians
     */
    public var angle: b2Float {
        return b2Atan2(s, c)
    }
    /**
     Get the x-axis
     */
    public var xAxis: b2Vec2 {
        return b2Vec2(c, s)
    }
    /**
     Get the u-axis
     */
    public var yAxis: b2Vec2 {
        return b2Vec2(-s, c)
    }
    public var description: String {
        get {
            return "(s:\(s),c:\(c))"
        }
    }
    /**
     Sine and cosine
     */
    public var s: b2Float
    public var c: b2Float
}

/**
 A transform contains translation and rotation. It is used to represent
 the position and orientation of rigid frames.
 */
public struct b2Transform : CustomStringConvertible {
    /**
     The default constructor does nothing.
     */
    public init() {
        p = b2Vec2()
        q = b2Rot()
    }
    /**
     Initialize using a position vector and a rotation.
     */
    public init(position: b2Vec2, rotation: b2Rot) {
        p = position
        q = rotation
    }
    /**
     Set this to the identity transform.
     */
    public mutating func setIdentity() {
        p.setZero()
        q.setIdentity()
    }
    /**
     Set this based on the position and angle.
     */
    public mutating func set(_ position: b2Vec2, angle: b2Float) {
        p = position
        q.set(angle)
    }
    public var description: String {
        get {
            return "(p:\(p),q:\(q))"
        }
    }
    
    public var p: b2Vec2
    public var q: b2Rot
}

/**
 This describes the motion of a body/shape for TOI computation.
 Shapes are defined with respect to the body origin, which may
 no coincide with the center of mass. However, to support dynamics
 we must interpolate the center of mass position.
 */
public struct b2Sweep : CustomStringConvertible {
    public init() {}
    /**
     Get the interpolated transform at a specific time.
     
     - parameter beta: is a factor in [0,1], where 0 indicates alpha0.
     */
    public func getTransform(beta: b2Float) -> b2Transform {
        var xf = b2Transform()
        xf.p = (1.0 - beta) * c0 + beta * c
        let angle = (1.0 - beta) * a0 + beta * a
        xf.q.set(angle)
        
        // Shift to origin
        xf.p -= b2Mul(xf.q, localCenter)
        return xf
    }
    /**
     Advance the sweep forward, yielding a new initial state.
     
     - parameter alpha: the new initial time.
     */
    public mutating func advance(alpha: b2Float) {
        assert(alpha0 < 1.0)
        let beta = (alpha - alpha0) / (1.0 - alpha0)
        c0 += beta * (c - c0)
        a0 += beta * (a - a0)
        alpha0 = alpha
    }
    /**
     Normalize the angles.
     */
    public mutating func normalize() {
        let twoPi = 2.0 * b2_pi
        let d =  twoPi * floor(a0 / twoPi)
        a0 -= d
        a -= d
    }
    public var description: String {
        return "b2Sweep[localCenter=\(localCenter), c0=\(c0), c=\(c), a0=\(a0), a=\(a), alpha0=\(alpha0)]"
    }
    /**
     local center of mass position
     */
    public var localCenter = b2Vec2()
    /**
     center world positions
     */
    public var m_c0 = b2Vec2()
    public var c0 : b2Vec2 {
        get {
            return m_c0
        }
        set {
            m_c0 = newValue
        }
    }
    public var c = b2Vec2()
    /**
     world angles
     */
    public var a0: b2Float = 0, a: b2Float = 0
    /**
     Fraction of the current time step in the range [0,1]
     c0 and a0 are the positions at alpha0.
     */
    public var alpha0: b2Float = 0
}

/**
 Useful constant
 */
public let b2Vec2_zero = b2Vec2(0.0, 0.0)
/**
 Perform the dot product on two vectors.
 */
public func b2Dot(_ a : b2Vec2, _ b : b2Vec2) -> b2Float {
    return a.x * b.x + a.y * b.y
}
/**
 Perform the cross product on two vectors. In 2D this produces a scalar.
 */
public func b2Cross(_ a : b2Vec2, _ b : b2Vec2) -> b2Float {
    return a.x * b.y - a.y * b.x
}
/**
 Perform the cross product on a vector and a scalar. In 2D this produces
 a vector.
 */
public func b2Cross(_ a : b2Vec2, _ s : b2Float) -> b2Vec2 {
    return b2Vec2(s * a.y, -s * a.x)
}
/**
 Perform the cross product on a scalar and a vector. In 2D this produces
 a vector.
 */
public func b2Cross(_ s : b2Float, _ a : b2Vec2) -> b2Vec2 {
    return b2Vec2(-s * a.y, s * a.x)
}
/**
 Multiply a matrix times a vector. If a rotation matrix is provided,
 then this transforms the vector from one frame to another.
 */
public func b2Mul(_ A : b2Mat22, _ v : b2Vec2) -> b2Vec2 {
    return b2Vec2(b2Dot(v, A.ex), b2Dot(v, A.ey))
}
/**
 Multiply a matrix transpose times a vector. If a rotation matrix is provided,
 then this transforms the vector from one frame to another (inverse transform).
 */
public func b2MulT(_ A : b2Mat22, _ v : b2Vec2) -> b2Vec2 {
    return b2Vec2(b2Dot(v, A.ex), b2Dot(v, A.ey))
}
/**
 Add two vectors component-wise.
 */
public func + (a: b2Vec2, b: b2Vec2) -> b2Vec2 {
    return b2Vec2(a.x + b.x, a.y + b.y)
}
/**
 Subtract two vectors component-wise.
 */
public func - (a: b2Vec2, b: b2Vec2) -> b2Vec2 {
    return b2Vec2(a.x - b.x, a.y - b.y)
}

public func * (s: b2Float, a: b2Vec2) -> b2Vec2 {
    return b2Vec2(s * a.x, s * a.y)
}

public func == (a: b2Vec2, b: b2Vec2) -> Bool {
    return a.x == b.x && a.y == b.y
}

public func b2Distance(_ a : b2Vec2, _ b : b2Vec2) -> b2Float {
    let c = a - b
    return c.length()
}

public func b2DistanceSquared(_ a : b2Vec2, _ b: b2Vec2) -> b2Float {
    let c = a - b
    return b2Dot(c, c)
}

public func * (s : b2Float, a : b2Vec3) -> b2Vec3 {
    return b2Vec3(s * a.x, s * a.y, s * a.z)
}
/**
 Add two vectors component-wise.
 */
public func + (a : b2Vec3, b : b2Vec3) -> b2Vec3
{
    return b2Vec3(a.x + b.x, a.y + b.y, a.z + b.z)
}
/**
 Subtract two vectors component-wise.
 */
public func - (a : b2Vec3, b : b2Vec3) -> b2Vec3
{
    return b2Vec3(a.x - b.x, a.y - b.y, a.z - b.z)
}
/**
 Perform the dot product on two vectors.
 */
public func b2Dot(_ a : b2Vec3, _ b : b2Vec3) -> b2Float
{
    return a.x * b.x + a.y * b.y + a.z * b.z
}
/**
 Perform the cross product on two vectors.
 */
public func b2Cross(_ a : b2Vec3, _ b : b2Vec3) -> b2Vec3
{
    return b2Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

public func + (A : b2Mat22, B : b2Mat22) -> b2Mat22
{
    return b2Mat22(A.ex + B.ex, A.ey + B.ey)
}
/**
 A * B
 */
public func b2Mul(_ A : b2Mat22, _ B : b2Mat22) -> b2Mat22
{
    return b2Mat22(b2Mul(A, B.ex), b2Mul(A, B.ey))
}
/**
 A^T * B
 */
public func b2MulT(_ A : b2Mat22, _ B : b2Mat22) -> b2Mat22
{
    let c1 = b2Vec2(b2Dot(A.ex, B.ex), b2Dot(A.ey, B.ex))
    let c2 = b2Vec2(b2Dot(A.ex, B.ey), b2Dot(A.ey, B.ey))
    return b2Mat22(c1, c2)
}
/**
 Multiply a matrix times a vector.
 */
public func b2Mul(_ A : b2Mat33, _ v : b2Vec3) -> b2Vec3
{
    return v.x * A.ex + v.y * A.ey + v.z * A.ez
}
/**
 Multiply a matrix times a vector.
 */
public func b2Mul22(_ A : b2Mat33, _ v : b2Vec2) -> b2Vec2
{
    return b2Vec2(A.ex.x * v.x + A.ey.x * v.y, A.ex.y * v.x + A.ey.y * v.y)
}

/**
 Multiply two rotations: q * r
 */
public func b2Mul(_ q : b2Rot, _ r : b2Rot) -> b2Rot
{
    // [qc -qs] * [rc -rs] = [qc*rc-qs*rs -qc*rs-qs*rc]
    // [qs  qc]   [rs  rc]   [qs*rc+qc*rs -qs*rs+qc*rc]
    // s = qs * rc + qc * rs
    // c = qc * rc - qs * rs
    var qr = b2Rot()
    qr.s = q.s * r.c + q.c * r.s
    qr.c = q.c * r.c - q.s * r.s
    return qr
}
/**
 Transpose multiply two rotations: qT * r
 */
public func b2MulT(_ q : b2Rot, _ r : b2Rot) -> b2Rot
{
    // [ qc qs] * [rc -rs] = [qc*rc+qs*rs -qc*rs+qs*rc]
    // [-qs qc]   [rs  rc]   [-qs*rc+qc*rs qs*rs+qc*rc]
    // s = qc * rs - qs * rc
    // c = qc * rc + qs * rs
    var qr = b2Rot()
    qr.s = q.c * r.s - q.s * r.c
    qr.c = q.c * r.c + q.s * r.s
    return qr
}
/**
 Rotate a vector
 */
public func b2Mul(_ q : b2Rot, _ v : b2Vec2) -> b2Vec2
{
    return b2Vec2(q.c * v.x - q.s * v.y, q.s * v.x + q.c * v.y)
}
/**
 Inverse rotate a vector
 */
public func b2MulT(_ q : b2Rot, _ v : b2Vec2) -> b2Vec2
{
    return b2Vec2(q.c * v.x + q.s * v.y, -q.s * v.x + q.c * v.y)
}

public func b2Mul(_ T : b2Transform, _ v : b2Vec2) -> b2Vec2
{
    let x = (T.q.c * v.x - T.q.s * v.y) + T.p.x
    let y = (T.q.s * v.x + T.q.c * v.y) + T.p.y
    
    return b2Vec2(x, y)
}

public func b2MulT(_ T : b2Transform, _ v : b2Vec2) -> b2Vec2
{
    let px = v.x - T.p.x
    let py = v.y - T.p.y
    let x = (T.q.c * px + T.q.s * py)
    let y = (-T.q.s * px + T.q.c * py)
    
    return b2Vec2(x, y)
}
/**
 v2 = A.q.Rot(B.q.Rot(v1) + B.p) + A.p
 = (A.q * B.q).Rot(v1) + A.q.Rot(B.p) + A.p
 */
public func b2Mul(_ A : b2Transform, _ B : b2Transform) -> b2Transform
{
    var C = b2Transform()
    C.q = b2Mul(A.q, B.q)
    C.p = b2Mul(A.q, B.p) + A.p
    return C
}
/**
 v2 = A.q' * (B.q * v1 + B.p - A.p)
 = A.q' * B.q * v1 + A.q' * (B.p - A.p)
 */
public func b2MulT(_ A : b2Transform, _ B : b2Transform) -> b2Transform
{
    var C = b2Transform()
    C.q = b2MulT(A.q, B.q)
    C.p = b2MulT(A.q, B.p - A.p)
    return C
}

public func b2Abs(_ a : b2Vec2) -> b2Vec2 {
    return b2Vec2(abs(a.x), abs(a.y))
}

public func b2Abs(_ A : b2Mat22) -> b2Mat22 {
    return b2Mat22(b2Abs(A.ex), b2Abs(A.ey))
}

public func b2Min(_ a : b2Vec2, _ b : b2Vec2) -> b2Vec2 {
    return b2Vec2(min(a.x, b.x), min(a.y, b.y))
}

public func b2Max(_ a : b2Vec2, _ b : b2Vec2) -> b2Vec2 {
    return b2Vec2(max(a.x, b.x), max(a.y, b.y))
}

public func b2Clamp(_ a : b2Float, _ low : b2Float, _ high : b2Float) -> b2Float {
    return max(low, min(a, high))
}

public func b2Clamp(_ a : b2Vec2, _ low : b2Vec2, _ high : b2Vec2) -> b2Vec2
{
    return b2Max(low, b2Min(a, high))
}
/**
 Given a binary integer value x, the next largest power of 2 can be computed by a SWAR algorithm
 that recursively "folds" the upper bits into the lower bits. This process yields a bit vector with
 the same most significant 1 as x, but all 1's below it. Adding 1 to that value yields the next
 largest power of 2. For a 32-bit value:"
 */
public func b2NextPowerOfTwo(_ _x : UInt) -> UInt {
    var x = _x
    x |= (x >> 1)
    x |= (x >> 2)
    x |= (x >> 4)
    x |= (x >> 8)
    x |= (x >> 16)
    return x + 1
}

public func b2IsPowerOfTwo(_ x : UInt) -> Bool
{
    let result = x > 0 && (x & (x - 1)) == 0
    return result
}
