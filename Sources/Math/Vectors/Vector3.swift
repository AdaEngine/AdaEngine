//
//  Vector3.swift
//  
//
//  Created by v.prusakov on 6/22/22.
//

import simd

public typealias Vector3 = SIMD3<Float>

extension Vector3 {
    public var description: String {
        return String(describing: type(of: self)) + "(\(x), \(y), \(z))"
    }
}

public extension Vector3 {
    static func * (lhs: Transform2D, rhs: Vector3) -> Vector3 {
        [
            lhs[0, 0] * rhs.x + lhs[1, 0] * rhs.y + lhs[2, 0] * rhs.z,
            lhs[0, 1] * rhs.x + lhs[1, 1] * rhs.y + lhs[2, 1] * rhs.z,
            lhs[0, 2] * rhs.x + lhs[1, 2] * rhs.y + lhs[2, 2] * rhs.z
        ]
    }
}

public extension Vector3 {
    func cross(_ vec: Vector3) -> Vector3 {
        var x1 = self.y * vec.z
        x1 = x1 - vec.y * self.z
        var y1 = self.z * vec.x
        y1 = y1 - vec.z * self.x
        var z1 = self.x * vec.y
        z1 = z1 - vec.x * self.y
        
        return Vector3(x1, y1, z1)
    }
    
    var squaredLength: Float {
        return x * x + y * y + z * z
    }
    
    var length: Float {
        return sqrt(squaredLength)
    }
    
    var normalized: Vector3 {
        return self / self.length
    }
    
    func dot(_ vector: Vector3) -> Float {
        return x * vector.x + y * vector.y + z * vector.z
    }
    
    static let up: Vector3 = Vector3(0, 1, 0)
    
    static let down: Vector3 = Vector3(0, -1, 0)
    
    static let left: Vector3 = Vector3(-1, 0, 0)
    
    static let right: Vector3 = Vector3(1, 0, 0)
}
