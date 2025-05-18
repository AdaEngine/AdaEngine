//
//  Quat.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/12/21.
//

// swiftlint:disable identifier_name

/// The struct describe Quaternion
public struct Quat: Codable, Sendable {
    public var x: Float
    public var y: Float
    public var z: Float
    public var w: Float
}

extension Quat: Equatable, Hashable {}

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
    
    /// Returns a rotation that rotates z degrees around the z axis,
    /// x degrees around the x axis, and y degrees around the y axis; applied in that order.
    static func euler(_ vector: Vector3) -> Quat {
        let c1 = cos(vector.y / 2)
        let c2 = cos(vector.x / 2)
        let c3 = cos(vector.z / 2)
        
        let s1 = sin(vector.y / 2)
        let s2 = sin(vector.x / 2)
        let s3 = sin(vector.z / 2)
        
        return Quat(
            x: s1 * c2 * c3 + c1 * s2 * s3,
            y: c1 * s2 * c3 - s1 * c2 * s3,
            z: c1 * c2 * s3 + s1 * s2 * c3,
            w: c1 * c2 * c3 - s1 * s2 * s3
        )
    }
    
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

// swiftlint:enable identifier_name
