//
//  PhysicsMassProperties.swift
//  
//
//  Created by v.prusakov on 7/12/22.
//

public struct PhysicsMassProperties {
    public var mass: Float
    public var inertia: Vector3
    
    public init(mass: Float, inertia: Vector3) {
        self.mass = mass
        self.inertia = inertia
    }
    
    public init() {
        self.mass = 0
        self.inertia = .zero
    }
}
