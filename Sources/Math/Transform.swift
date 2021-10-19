//
//  Matrix4.swift
//  
//
//  Created by v.prusakov on 10/19/21.
//

import simd

@frozen
public struct Transform {
    var storage: [Vector4]
    
    @inline(__always)
    public init() {
        self.storage = [
            Vector4(1, 0, 0, 0),
            Vector4(0, 1, 0, 0),
            Vector4(0, 0, 1, 0),
            Vector4(0, 0, 0, 0),
        ]
    }
    
    public subscript (_ column: Int, _ row: Int) -> Float {
        get {
            self.storage[column][row]
        }
        
        set {
            self.storage[column][row] = newValue
        }
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
        self.storage = identity.storage
    }
    
    @inline(__always)
    init(diagonal: Vector3) {
        var identity = Transform.identity
        identity[0, 1] = diagonal.x
        identity[1, 1] = diagonal.y
        identity[2, 2] = diagonal.z
        self.storage = identity.storage
    }
    
    @inline(__always)
    init(columns: [Vector4]) {
        self.storage = columns
    }
    
}

public extension Transform {
    @inline(__always)
    static let identity: Transform = Transform()
}

public extension Transform {
    static func * (lhs: Transform, rhs: Float) -> Transform {
        Transform(columns: [
            Vector4(lhs[0, 0] * rhs, lhs[0, 1] * rhs, lhs[0, 2] * rhs, lhs[0, 3] * rhs),
            Vector4(lhs[1, 0] * rhs, lhs[1, 1] * rhs, lhs[1, 2] * rhs, lhs[1, 3] * rhs),
            Vector4(lhs[2, 0] * rhs, lhs[2, 1] * rhs, lhs[2, 2] * rhs, lhs[2, 3] * rhs),
            Vector4(lhs[3, 0] * rhs, lhs[3, 1] * rhs, lhs[3, 2] * rhs, lhs[3, 3] * rhs),
        ])
    }
    
    static func * (lhs: Transform, rhs: Transform) -> Transform {
        Transform(columns: [
            Vector4(lhs[0, 0] * rhs[0, 0], lhs[0, 1] * rhs[0, 1], lhs[0, 2] * rhs[0, 2], lhs[0, 3] * rhs[0, 3]),
            Vector4(lhs[1, 0] * rhs[1, 0], lhs[1, 1] * rhs[1, 1], lhs[1, 2] * rhs[1, 2], lhs[1, 3] * rhs[1, 3]),
            Vector4(lhs[2, 0] * rhs[2, 0], lhs[2, 1] * rhs[2, 1], lhs[2, 2] * rhs[2, 2], lhs[2, 3] * rhs[2, 3]),
            Vector4(lhs[3, 0] * rhs[3, 0], lhs[3, 1] * rhs[3, 1], lhs[3, 2] * rhs[3, 2], lhs[3, 3] * rhs[3, 3]),
        ])
    }
    
    static prefix func - (matrix: Transform) -> Transform {
        Transform(columns: [
            Vector4(-matrix[0, 0], -matrix[0, 1], -matrix[0, 2], -matrix[0, 3]),
            Vector4(-matrix[1, 0], -matrix[1, 1], -matrix[1, 2], -matrix[1, 3]),
            Vector4(-matrix[2, 0], -matrix[2, 1], -matrix[2, 2], -matrix[2, 3]),
            Vector4(-matrix[3, 0], -matrix[3, 1], -matrix[3, 2], -matrix[3, 3]),
        ])
    }
}


//extension Transform {
//    func lookAt(eye: Vector3, target: Vector3, up: Vector3 = .up) -> Transform {
//        let viewZ = -target.normalized
//        let viewX = up.cross(viewZ).normalized
//        let viewY = viewZ.cross(viewX)
//
//        return Transform(columns: [
//            Vector4(<#T##v0: Float##Float#>, <#T##v1: Float##Float#>, <#T##v2: Float##Float#>, <#T##v3: Float##Float#>)
//        ])
//    }
//}
