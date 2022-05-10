//
//  Quat.swift
//  
//
//  Created by v.prusakov on 11/12/21.
//

/// The struct describe Quaternion
public struct Quat {
    public var x: Float
    public var y: Float
    public var z: Float
    public var w: Float
}

extension Quat: Codable, Equatable, Hashable {}

extension Quat: CustomStringConvertible {
    public var description: String {
        return "Quat: (\(x), \(y), \(z), \(w))"
    }
}

public extension Quat {
    
    static let identity = Quat(x: 0, y: 0, z: 0, w: 1)
    
    init() {
        self.x = 0
        self.y = 0
        self.z = 0
        self.w = 0
    }
    
    init(rotationMatrix matrix: Transform3D) {
        var quat = Quat.identity
        quat.w = sqrt(max(0, 1 + matrix[0, 0] + matrix[1, 1] + matrix[2, 2])) / 2
        quat.x = sqrt(max(0, 1 + matrix[0, 0] - matrix[1, 1] - matrix[2, 2])) / 2
        quat.y = sqrt(max(0, 1 - matrix[0, 0] + matrix[1, 1] - matrix[2, 2])) / 2
        quat.z = sqrt(max(0, 1 - matrix[0, 0] - matrix[1, 1] + matrix[2, 2])) / 2
        
        quat.x *= sign(quat.x * (matrix[2, 1] - matrix[1, 2]))
        quat.y *= sign(quat.y * (matrix[0, 2] - matrix[2, 0]))
        quat.z *= sign(quat.z * (matrix[1, 0] - matrix[0, 1]))
        
        self = quat
    }
    
    init(axis: Vector3, angle: Float) {
        let d = axis.length
        
        if d == 0 {
            self = Quat()
        } else {
            let sinAngle = sin(angle * 0.5)
            let cosAngle = cos(angle * 0.5)
            
            let s = sinAngle / d
            self.x = axis.x * s
            self.y = axis.y * s
            self.z = axis.z * s
            self.w = cosAngle
        }
    }
}

public extension Quat {
    func dot(_ quat: Quat) -> Float {
        return self.x * quat.x + self.y * quat.y + self.z * quat.z + self.w * quat.w
    }
    
    func angle(to quat: Quat) -> Float {
        let dot = self.dot(quat)
        return acos(clamp(dot * dot * 2 - 1, -1, 1))
    }
    
    var squaredLength: Float {
        return x * x + y * y + z * z + w * w
    }
    
    var normalized: Quat {
        let normal = sqrt(self.squaredLength)
        
        return Quat(
            x: self.x / normal,
            y: self.y / normal,
            z: self.z / normal,
            w: self.w / normal
        )
    }
    
}

public extension Quat {
    static func * (lhs: Quat, v: Vector3) -> Quat {
        Quat(
            x: lhs.w * v.x + lhs.y * v.z - lhs.z * v.y,
            y: lhs.w * v.y + lhs.z * v.x - lhs.x * v.z,
            z: lhs.w * v.z + lhs.x * v.y - lhs.y * v.x,
            w: -lhs.x * v.x - lhs.y * v.y - lhs.z * v.z
        )
    }
}

#if canImport(simd)
import simd

public extension Quat {
    init(_ simd_quat: simd_quatf) {
        self.x = simd_quat.vector.x
        self.y = simd_quat.vector.y
        self.z = simd_quat.vector.z
        self.w = simd_quat.vector.w
    }
}

#endif
