//
//  Matrix4.swift
//  
//
//  Created by v.prusakov on 10/19/21.
//

#if (os(OSX) || os(iOS) || os(tvOS) || os(watchOS))
import Darwin
#elseif os(Linux) || os(Android)
import Glibc
#endif

@frozen
public struct Transform {
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

public extension Transform {
    
    @inline(__always)
    init(scale: Vector3) {
        self = Transform(diagonal: scale)
    }
    
    @inline(__always)
    init(translation: Vector3) {
        var identity = Transform.identity
        identity[0, 3] = translation.x
        identity[1, 3] = translation.y
        identity[2, 3] = translation.z
        self = identity
    }
    
    @inline(__always)
    init(diagonal: Vector3) {
        var identity = Transform.identity
        identity[0, 1] = diagonal.x
        identity[1, 1] = diagonal.y
        identity[2, 2] = diagonal.z
        self = identity
    }
    
    @inline(__always)
    init(columns: [Vector4]) {
        precondition(columns.count > 4, "Inconsist columns count")
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

extension Transform: CustomDebugStringConvertible {
    public var debugDescription: String {
        return String(describing: type(of: self)) + "(" + [x, y, z, w].map { (v: Vector4) -> String in
            "[" + [v.x, v.y, v.z, v.w].map { String(describing: $0) }.joined(separator: ", ") + "]"
        }.joined(separator: ", ") + ")"
    }
}

public extension Transform {
    
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
    static let identity: Transform = Transform()
}

public extension Transform {
    static func * (lhs: Transform, rhs: Float) -> Transform {
        Transform(
            Vector4(lhs[0, 0] * rhs, lhs[0, 1] * rhs, lhs[0, 2] * rhs, lhs[0, 3] * rhs),
            Vector4(lhs[1, 0] * rhs, lhs[1, 1] * rhs, lhs[1, 2] * rhs, lhs[1, 3] * rhs),
            Vector4(lhs[2, 0] * rhs, lhs[2, 1] * rhs, lhs[2, 2] * rhs, lhs[2, 3] * rhs),
            Vector4(lhs[3, 0] * rhs, lhs[3, 1] * rhs, lhs[3, 2] * rhs, lhs[3, 3] * rhs)
        )
    }
    
    static func * (lhs: Transform, rhs: Transform) -> Transform {
        Transform(
            Vector4(lhs[0, 0] * rhs[0, 0], lhs[0, 1] * rhs[0, 1], lhs[0, 2] * rhs[0, 2], lhs[0, 3] * rhs[0, 3]),
            Vector4(lhs[1, 0] * rhs[1, 0], lhs[1, 1] * rhs[1, 1], lhs[1, 2] * rhs[1, 2], lhs[1, 3] * rhs[1, 3]),
            Vector4(lhs[2, 0] * rhs[2, 0], lhs[2, 1] * rhs[2, 1], lhs[2, 2] * rhs[2, 2], lhs[2, 3] * rhs[2, 3]),
            Vector4(lhs[3, 0] * rhs[3, 0], lhs[3, 1] * rhs[3, 1], lhs[3, 2] * rhs[3, 2], lhs[3, 3] * rhs[3, 3])
        )
    }
    
    static prefix func - (matrix: Transform) -> Transform {
        Transform(
            Vector4(-matrix[0, 0], -matrix[0, 1], -matrix[0, 2], -matrix[0, 3]),
            Vector4(-matrix[1, 0], -matrix[1, 1], -matrix[1, 2], -matrix[1, 3]),
            Vector4(-matrix[2, 0], -matrix[2, 1], -matrix[2, 2], -matrix[2, 3]),
            Vector4(-matrix[3, 0], -matrix[3, 1], -matrix[3, 2], -matrix[3, 3])
        )
    }
}


public extension Transform {
    /// Left Handsome
    static func lookAt(eye: Vector3, target: Vector3, up: Vector3 = .up) -> Transform {
        let f = (target - eye).normalized
        let s = f.cross(up).normalized
        let u = s.cross(f)
        
        let rotate30 = -s.dot(eye)
        let rotate31 = -u.dot(eye)
        let rotate32 = f.dot(eye)
        
        return Transform(
            Vector4(s.x, u.x, -f.x, 0),
            Vector4(s.y, u.y, -f.y, 0),
            Vector4(s.z, u.z, -f.z, 0),
            Vector4(rotate30, rotate31, rotate32, 1)
        )
    }
    
    /// Left Handsome
    static func perspective(_ fieldOfView: Float, aspect: Float, zNear: Float, zFar: Float) -> Transform {
        precondition(aspect > 0, "Aspect should be more than 0")
        let tanHalfFieldOfView = tan(fieldOfView / 2)
        
        let rotate01 = 1 / (aspect * tanHalfFieldOfView)
        let rotate11 = 1 / tanHalfFieldOfView
        
        let rotate22 = -(zFar + zNear) / (zFar - zNear)
        var rotate32 = -(2 * zFar * zNear)
        rotate32 /= (zFar - zNear)
        
        return Transform(
            Vector4(rotate01, 0, 0, 0),
            Vector4(0, rotate11, 0, 0),
            Vector4(0, 0, rotate22, -1),
            Vector4(0, 0, rotate32, 0)
        )
    }
    
    func rotate(angle: Angle, vector: Vector3) -> Transform {
        let c = cos(angle.degrees)
        let s = sin(angle.degrees)
        
        let axis = vector.normalized
        
        var r00: Float = c
        r00 += (1 - c) * axis.x * axis.x
        var r01: Float = (1 - c) * axis.x * axis.y
        r01 += s * axis.z
        var r02: Float = (1 - c) * axis.x * axis.z
        r02 -= s * axis.y
        
        var r10: Float = (1 - c) * axis.y * axis.x
        r10 -= s * axis.z
        var r11: Float = c
        r11 += (1 - c) * axis.y * axis.y
        var r12: Float = (1 - c) * axis.y * axis.z
        r12 += s * axis.x
        
        var r20: Float = (1 - c) * axis.z * axis.x
        r20 += s * axis.y
        var r21: Float = (1 - c) * axis.z * axis.y
        r21 -= s * axis.x
        var r22: Float = c
        r22 += (1 - c) * axis.z * axis.z
        
        return Transform(
            Vector4(r00, r01, r02, 0),
            Vector4(r10, r11, r12, 0),
            Vector4(r20, r21, r22, 0),
            Vector4(0, 0, 0, 1)
        )
    }
}
