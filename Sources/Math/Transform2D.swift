//
//  Transform2D.swift
//  
//
//  Created by v.prusakov on 10/20/21.
//

#if (os(OSX) || os(iOS) || os(tvOS) || os(watchOS))
import Darwin
#elseif os(Linux) || os(Android)
import Glibc
#endif

@frozen
public struct Transform2D {
    var x: Vector3
    var y: Vector3
    var z: Vector3
    
    @inline(__always)
    public init() {
        self.x = Vector3(1, 0, 0)
        self.y = Vector3(0, 1, 0)
        self.z = Vector3(0, 0, 1)
    }
    
    public var rotation: Float {
        fatalError()
    }
    
    public var scale: Float {
        fatalError()
    }
}

public extension Transform2D {
    init(translation: Vector2) {
        var identity = Transform2D.identity
        identity[2, 0] = translation.x
        identity[2, 1] = translation.y
        self = identity
    }
    
    init(scale: Vector2) {
        var identity = Transform2D.identity
        identity[0, 0] = scale.x
        identity[1, 1] = scale.y
        self = identity
    }
    
    init(rotation: Angle) {
        var identity = Transform2D.identity
        identity[0, 0] = cos(rotation.degrees)
        identity[0, 1] = sin(rotation.degrees)
        identity[1, 0] = -sin(rotation.degrees)
        identity[1, 1] = cos(rotation.degrees)
        self = identity
    }
    
    init(columns: [Vector3]) {
        precondition(columns.count > 3, "Inconsist columns count")
        self.x = columns[0]
        self.y = columns[1]
        self.z = columns[2]
    }
    
    init(diagonal: Float) {
        var identity = Transform2D.identity
        identity[0, 0] = diagonal
        identity[1, 1] = diagonal
        identity[2, 2] = diagonal
        self = identity
    }
}

public extension Transform2D {
    
    @inline(__always)
    subscript (_ column: Int, _ row: Int) -> Float {
        get {
            self[column][row]
        }
        
        set {
            self[column][row] = newValue
        }
    }
    
    @inline(__always)
    subscript (column: Int) -> Vector3 {
        get {
            switch(column) {
            case 0: return x
            case 1: return y
            case 2: return z
            default: preconditionFailure("Matrix index out of range")
            }
        }
        set {
            switch(column) {
            case 0: x = newValue
            case 1: y = newValue
            case 2: z = newValue
            default: preconditionFailure("Matrix index out of range")
            }
        }
    }
    
    @inline(__always)
    static let identity: Transform2D = Transform2D()
}

extension Transform2D: Equatable { }

public extension Transform2D {
    static func * (lhs: Transform2D, rhs: Float) -> Transform2D {
        Transform2D(columns: [
            Vector3(lhs[0, 0] * rhs, lhs[0, 1] * rhs, lhs[0, 2] * rhs),
            Vector3(lhs[1, 0] * rhs, lhs[1, 1] * rhs, lhs[1, 2] * rhs),
            Vector3(lhs[2, 0] * rhs, lhs[2, 1] * rhs, lhs[2, 2] * rhs),
        ])
    }
    
    static func * (lhs: Transform2D, rhs: Transform2D) -> Transform2D {
        Transform2D(columns: [
            Vector3(lhs[0, 0] * rhs[0, 0], lhs[0, 1] * rhs[0, 1], lhs[0, 2] * rhs[0, 2]),
            Vector3(lhs[1, 0] * rhs[1, 0], lhs[1, 1] * rhs[1, 1], lhs[1, 2] * rhs[1, 2]),
            Vector3(lhs[2, 0] * rhs[2, 0], lhs[2, 1] * rhs[2, 1], lhs[2, 2] * rhs[2, 2]),
        ])
    }
    
    static prefix func -(matrix: Transform2D) -> Transform2D {
        Transform2D(columns: [
            Vector3(-matrix[0, 0], -matrix[0, 1], -matrix[0, 2]),
            Vector3(-matrix[1, 0], -matrix[1, 1], -matrix[1, 2]),
            Vector3(-matrix[2, 0], -matrix[2, 1], -matrix[2, 2]),
        ])
    }
}
