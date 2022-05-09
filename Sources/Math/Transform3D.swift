//
//  Tranform3D.swift
//  
//
//  Created by v.prusakov on 10/19/21.
//

#if (os(OSX) || os(iOS) || os(tvOS) || os(watchOS))
import Darwin
#elseif os(Linux) || os(Android)
import Glibc
import SGLMath
#endif
import simd

@frozen
public struct Transform3D: Hashable {
    public var x: Vector4
    public var y: Vector4
    public var z: Vector4
    public var w: Vector4
    
    @inline(__always)
    public init() {
        self.x = Vector4(1, 0, 0, 0)
        self.y = Vector4(0, 1, 0, 0)
        self.z = Vector4(0, 0, 1, 0)
        self.w = Vector4(0, 0, 0, 1)
    }
}

extension Transform3D: Codable {}

public extension Transform3D {
    
    @inline(__always)
    init(scale: Vector3) {
        self = Transform3D(diagonal: scale)
    }
    
    @inline(__always)
    init(translation: Vector3) {
        var identity = Transform3D.identity
        identity[0, 3] = translation.x
        identity[1, 3] = translation.y
        identity[2, 3] = translation.z
        self = identity
    }
    
    @inline(__always)
    init(diagonal: Vector3) {
        var identity = Transform3D.identity
        identity[0, 0] = diagonal.x
        identity[1, 1] = diagonal.y
        identity[2, 2] = diagonal.z
        self = identity
    }
    
    @inline(__always)
    init(columns: [Vector4]) {
        precondition(columns.count == 4, "Inconsist columns count")
        self.x = columns[0]
        self.y = columns[1]
        self.z = columns[2]
        self.w = columns[3]
    }
    
    @inline(__always)
    init(_ x: Vector4, _ y: Vector4, _ z: Vector4, _ w: Vector4) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    
    @inline(__always)
    init(x: Vector4, y: Vector4, z: Vector4, w: Vector4) {
        self.init(x, y, z, w)
    }
    
}

extension Transform3D: CustomDebugStringConvertible {
    public var debugDescription: String {
        return String(describing: type(of: self)) + "(" + [x, y, z, w].map { (v: Vector4) -> String in
            "[" + [v.x, v.y, v.z, v.w].map { String(describing: $0) }.joined(separator: ", ") + "]"
        }.joined(separator: ", ") + ")"
    }
}

public extension Transform3D {
    
    subscript (_ column: Int, _ row: Int) -> Float {
        get {
            self[column][row]
        }
        
        set {
            self[column][row] = newValue
        }
    }
    
    subscript (column: Int) -> Vector4 {
        get {
            switch(column) {
            case 0: return x
            case 1: return y
            case 2: return z
            case 3: return w
            default: preconditionFailure("Matrix index out of range")
            }
        }
        set {
            switch(column) {
            case 0: x = newValue
            case 1: y = newValue
            case 2: z = newValue
            case 3: w = newValue
            default: preconditionFailure("Matrix index out of range")
            }
        }
    }
    
    @inline(__always)
    static let identity: Transform3D = Transform3D()
}

public extension Transform3D {
    
    var basis: Transform2D {
        return Transform2D(columns: [
            [self.x.x, self.x.y, self.x.z],
            [self.y.x, self.y.y, self.y.z],
            [self.z.x, self.z.y, self.z.z],
        ])
    }
    
    var scale: Vector3 {
        get {
            let basis = self.basis
            let scaleX = basis.x.length
            let scaleY = basis.y.length
            let scaleZ = basis.z.length
            
            return Vector3(scaleX, scaleY, scaleZ)
        }
        
        set {
            self = Transform3D(scale: newValue) * self
        }
    }
    
    
    /// - SeeAlso: http://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/index.htm
    var rotation: Quat {
        self.basis.rotation
    }
    
    var origin: Vector3 {
        get {
            return Vector3(self[0, 3], self[1, 3], self[2, 3])
        }
        
        mutating set {
            self[0, 3] = newValue.x
            self[1, 3] = newValue.y
            self[2, 3] = newValue.z
        }
    }
}

public extension Transform3D {
    
    /// - SeeAlso: https://stackoverflow.com/questions/1556260/convert-quaternion-rotation-to-rotation-matrix
    
    init(quat: Quat) {
        var matrix = Transform3D.identity
        
        let q = quat.normalized
        
        matrix[0, 0] = 1.0 - 2.0 * q.y * q.y - 2.0 * q.z * q.z
        matrix[0, 1] = 2.0 * q.x * q.y - 2.0 * q.z * q.w
        matrix[0, 2] = 2.0 * q.x * q.z + 2.0 * q.y * q.w
        
        matrix[1, 0] = 2.0 * q.x * q.y + 2.0 * q.z * q.w
        matrix[1, 1] = 1.0 - 2.0 * q.x * q.x - 2.0 * q.z * q.z
        matrix[1, 2] = 2.0 * q.y * q.z - 2.0 * q.x * q.w
        
        matrix[2, 0] = 2.0 * q.x * q.z - 2.0 * q.y * q.w
        matrix[2, 1] = 2.0 * q.y * q.z + 2.0 * q.x * q.w
        matrix[2, 2] = 1.0 - 2.0 * q.x * q.x - 2.0 * q.y * q.y
        
        self = matrix
    }
}

public extension Transform3D {
    static func * (lhs: Transform3D, rhs: Float) -> Transform3D {
        Transform3D(
            Vector4(lhs[0, 0] * rhs, lhs[0, 1] * rhs, lhs[0, 2] * rhs, lhs[0, 3] * rhs),
            Vector4(lhs[1, 0] * rhs, lhs[1, 1] * rhs, lhs[1, 2] * rhs, lhs[1, 3] * rhs),
            Vector4(lhs[2, 0] * rhs, lhs[2, 1] * rhs, lhs[2, 2] * rhs, lhs[2, 3] * rhs),
            Vector4(lhs[3, 0] * rhs, lhs[3, 1] * rhs, lhs[3, 2] * rhs, lhs[3, 3] * rhs)
        )
    }
    
    static func * (lhs: Transform3D, rhs: Transform3D) -> Transform3D {
        var x: Vector4 = lhs.x * rhs[0].x
        x = x + lhs.y * rhs[0].y
        x = x + lhs.z * rhs[0].z
        x = x + lhs.w * rhs[0].w
        var y: Vector4 = lhs.x * rhs[1].x
        y = y + lhs.y * rhs[1].y
        y = y + lhs.z * rhs[1].z
        y = y + lhs.w * rhs[1].w
        var z: Vector4 = lhs.x * rhs[2].x
        z = z + lhs.y * rhs[2].y
        z = z + lhs.z * rhs[2].z
        z = z + lhs.w * rhs[2].w
        var w: Vector4 = lhs.x * rhs.w.x
        w = w + lhs.y * rhs[3].y
        w = w + lhs.z * rhs[3].z
        w = w + lhs.w * rhs[3].w
        return Transform3D(x, y, z, w)
    }
    
    static func *= (lhs: inout Transform3D, rhs: Transform3D) {
        lhs = lhs * rhs
    }
    
    static prefix func - (matrix: Transform3D) -> Transform3D {
        Transform3D(
            Vector4(-matrix[0, 0], -matrix[0, 1], -matrix[0, 2], -matrix[0, 3]),
            Vector4(-matrix[1, 0], -matrix[1, 1], -matrix[1, 2], -matrix[1, 3]),
            Vector4(-matrix[2, 0], -matrix[2, 1], -matrix[2, 2], -matrix[2, 3]),
            Vector4(-matrix[3, 0], -matrix[3, 1], -matrix[3, 2], -matrix[3, 3])
        )
    }
}


public extension Transform3D {
    /// Left-handed
    static func lookAt(eye: Vector3, center: Vector3, up: Vector3 = .up) -> Transform3D {
        let z = (center - eye).normalized
        let x = z.cross(up).normalized
        let y = x.cross(z)
        
        let rotate30 = -x.dot(eye)
        let rotate31 = -y.dot(eye)
        let rotate32 = -z.dot(eye)
        
        return Transform3D(
            Vector4(x.x, y.x, z.x, 0),
            Vector4(x.y, y.y, z.y, 0),
            Vector4(x.z, y.z, z.z, 0),
            Vector4(rotate30, rotate31, rotate32, 1)
        )
    }
    
    /// A left-handed perspective projection
    static func perspective(fieldOfView: Angle, aspectRatio: Float, zNear: Float, zFar: Float) -> Transform3D {
        precondition(aspectRatio > 0, "Aspect should be more than 0")
        
        let rotate11 = 1 / tanf(fieldOfView.radians * 0.5)
        let rotate01 = rotate11 / aspectRatio
        let rotate22 = zFar / (zFar - zNear)
        let rotate32 = -zNear * rotate22
        
        return Transform3D(
            Vector4(rotate01, 0, 0, 0),
            Vector4(0, rotate11, 0, 0),
            Vector4(0, 0, rotate22, 1),
            Vector4(0, 0, rotate32, 0)
        )
    }
    
    /// - SeeAlso: https://docs.microsoft.com/en-us/windows/win32/direct3d9/d3dxmatrixorthooffcenterlh
    static func orthogonal(
        left: Float,
        right: Float,
        top: Float,
        bottom: Float,
        zNear: Float,
        zFar: Float
    ) -> Transform3D {
        
        let m00 = 2/(right-left)
        let m11 = 2/(top-bottom)
        let m22 = 1/(zFar-zNear)
        let m03 = (left+right)/(left-right)
        let m13 = (top+bottom)/(bottom-top)
        let m23 = zNear/(zNear-zFar)
        
        return Transform3D(
            [m00, 0,   0,   0],
            [0,   m11, 0,   0],
            [0,   0,   m22, 0],
            [m03, m13, m23, 1]
        )
    }
    
    func rotate(angle: Angle, axis: Vector3) -> Transform3D {
        let c = cos(angle.radians)
        let s = sin(angle.radians)
        
        let axis = axis.normalized
        
        var r00 = c
        r00 += (1 - c) * axis.x * axis.x
        var r01 = (1 - c) * axis.x * axis.y
        r01 += s * axis.z
        var r02 = (1 - c) * axis.x * axis.z
        r02 -= s * axis.y
        
        var r10 = (1 - c) * axis.y * axis.x
        r10 -= s * axis.z
        var r11 = c
        r11 += (1 - c) * axis.y * axis.y
        var r12 = (1 - c) * axis.y * axis.z
        r12 += s * axis.x
        
        var r20 = (1 - c) * axis.z * axis.x
        r20 += s * axis.y
        var r21 = (1 - c) * axis.z * axis.y
        r21 -= s * axis.x
        var r22 = c
        r22 += (1 - c) * axis.z * axis.z
        
        return Transform3D(
            Vector4(r00, r01, r02, 0),
            Vector4(r10, r11, r12, 0),
            Vector4(r20, r21, r22, 0),
            Vector4(0, 0, 0, 1)
        )
    }
    
    var inverse: Transform3D {
        var d00 = self.x.x * self.y.y
        d00 = d00 - self.y.x * self.x.y
        var d01 = self.x.x * self.y.z
        d01 = d01 - self.y.x * self.x.z
        var d02 = self.x.x * self.y.w
        d02 = d02 - self.y.x * self.x.w
        var d03 = self.x.y * self.y.z
        d03 = d03 - self.y.y * self.x.z
        var d04 = self.x.y * self.y.w
        d04 = d04 - self.y.y * self.x.w
        var d05 = self.x.z * self.y.w
        d05 = d05 - self.y.z * self.x.w
        
        var d10 = self.z.x * self.w.y
        d10 = d10 - self.w.x * self.z.y
        var d11 = self.z.x * self.w.z
        d11 = d11 - self.w.x * self.z.z
        var d12 = self.z.x * self.w.w
        d12 = d12 - self.w.x * self.z.w
        var d13 = self.z.y * self.w.z
        d13 = d13 - self.w.y * self.z.z
        var d14 = self.z.y * self.w.w
        d14 = d14 - self.w.y * self.z.w
        var d15 = self.z.z * self.w.w
        d15 = d15 - self.w.z * self.z.w
        
        var det = d00 * d15
        det = det - d01 * d14
        det = det + d02 * d13
        det = det + d03 * d12
        det = det - d04 * d11
        det = det + d05 * d10
        
        var mm = Transform3D()
        
        mm.x.x = self.y.y * d15
        mm.x.x = mm.x.x - self.y.z * d14
        mm.x.x = mm.x.x + self.y.w * d13
        mm.x.y = 0 - self.x.y * d15
        mm.x.y = mm.x.y + self.x.z * d14
        mm.x.y = mm.x.y - self.x.w * d13
        mm.x.z = self.w.y * d05
        mm.x.z = mm.x.z - self.w.z * d04
        mm.x.z = mm.x.z + self.w.w * d03
        mm.x.w = 0 - self.z.y * d05
        mm.x.w = mm.x.w + self.z.z * d04
        mm.x.w = mm.x.w - self.z.w * d03
        
        mm.y.x = 0 - self.y.x * d15
        mm.y.x = mm.y.x + self.y.z * d12
        mm.y.x = mm.y.x - self.y.w * d11
        mm.y.y = self.x.x * d15
        mm.y.y = mm.y.y - self.x.z * d12
        mm.y.y = mm.y.y + self.x.w * d11
        mm.y.z = 0 - self.w.x * d05
        mm.y.z = mm.y.z + self.w.z * d02
        mm.y.z = mm.y.z - self.w.w * d01
        mm.y.w = self.z.x * d05
        mm.y.w = mm.y.w - self.z.z * d02
        mm.y.w = mm.y.w + self.z.w * d01
        
        mm.z.x = self.y.x * d14
        mm.z.x = mm.z.x - self.y.y * d12
        mm.z.x = mm.z.x + self.y.w * d10
        mm.z.y = 0 - self.x.x * d14
        mm.z.y = mm.z.y + self.x.y * d12
        mm.z.y = mm.z.y - self.x.w * d10
        mm.z.z = self.w.x * d04
        mm.z.z = mm.z.z - self.w.y * d02
        mm.z.z = mm.z.z + self.w.w * d00
        mm.z.w = 0 - self.z.x * d04
        mm.z.w = mm.z.w + self.z.y * d02
        mm.z.w = mm.z.w - self.z.w * d00
        
        mm.w.x = 0 - self.y.x * d13
        mm.w.x = mm.w.x + self.y.y * d11
        mm.w.x = mm.w.x - self.y.z * d10
        mm.w.y = self.x.x * d13
        mm.w.y = mm.w.y - self.x.y * d11
        mm.w.y = mm.w.y + self.x.z * d10
        mm.w.z = 0 - self.w.x * d03
        mm.w.z = mm.w.z + self.w.y * d01
        mm.w.z = mm.w.z - self.w.z * d00
        mm.w.w = self.z.x * d03
        mm.w.w = mm.w.w - self.z.y * d01
        mm.w.w = mm.w.w + self.z.z * d00
        
        let invdet = 1 / det
        return mm * invdet
    }
    
    var determinant: Float {
        var d00 = self.x.x * self.y.y
        d00 = d00 - self.y.x * self.x.y
        var d01 = self.x.x * self.y.z
        d01 = d01 - self.y.x * self.x.z
        var d02 = self.x.x * self.y.w
        d02 = d02 - self.y.x * self.x.w
        var d03 = self.x.y * self.y.z
        d03 = d03 - self.y.y * self.x.z
        var d04 = self.x.y * self.y.w
        d04 = d04 - self.y.y * self.x.w
        var d05 = self.x.z * self.y.w
        d05 = d05 - self.y.z * self.x.w
        
        var d10 = self.z.x * self.w.y
        d10 = d10 - self.w.x * self.z.y
        var d11 = self.z.x * self.w.z
        d11 = d11 - self.w.x * self.z.z
        var d12 = self.z.x * self.w.w
        d12 = d12 - self.w.x * self.z.w
        var d13 = self.z.y * self.w.z
        d13 = d13 - self.w.y * self.z.z
        var d14 = self.z.y * self.w.w
        d14 = d14 - self.w.y * self.z.w
        var d15 = self.z.z * self.w.w
        d15 = d15 - self.w.z * self.z.w
        
        var det = d00 * d15
        det = det - d01 * d14
        det = det + d02 * d13
        det = det + d03 * d12
        det = det - d04 * d11
        det = det + d05 * d10
        
        return det
    }
}
