//
//  Vector2.swift
//  
//
//  Created by v.prusakov on 8/12/21.
//

import simd

// TODO: Create object aka CGFloat for float or doubles
// TODO: when move to new vector object, we should use same object size

// swiftlint:disable identifier_name

/// Vector with floats
public typealias Vector2 = SIMD2<Float>

public extension Vector2 {
    var squaredLength: Float {
        return x * x + y * y
    }
    
    var normalized: Vector2 {
        let length = self.squaredLength
        return self / sqrt(length)
    }
    
    func dot(_ vector: Vector2) -> Float {
        return x * vector.x + y * vector.y
    }
}

extension Vector2 {
    public var description: String {
        return String(describing: type(of: self)) + "(\(x), \(y))"
    }
}

public typealias Point = Vector2

public extension Point {
    func applying(_ affineTransform: Transform2D) -> Point {
        let point = (affineTransform * Vector3(self.x, self.y, 1))
        return [point.x, point.y]
    }
}

// swiftlint:enable identifier_name
