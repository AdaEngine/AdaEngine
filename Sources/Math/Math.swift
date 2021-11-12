//
//  Math.swift
//  
//
//  Created by v.prusakov on 11/12/21.
//

public func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
    return value < min ? (min) : (value > max ? max : value)
}
