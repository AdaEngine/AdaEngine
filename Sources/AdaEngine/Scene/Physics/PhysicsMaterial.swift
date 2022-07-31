//
//  PhysicsMaterial.swift
//  
//
//  Created by v.prusakov on 7/12/22.
//

final public class PhysicsMaterial {
    
    let friction: Float
    let restitution: Float
    let density: Float
    
    internal init(friction: Float, restitution: Float, density: Float) {
        self.friction = friction
        self.restitution = restitution
        self.density = density
    }
    
    public static func generate(friction: Float, restitution: Float, density: Float) -> PhysicsMaterial {
        return PhysicsMaterial(friction: friction, restitution: restitution, density: density)
    }
}

public extension PhysicsMaterial {
    static let `default` = PhysicsMaterial(friction: 0.2, restitution: 0, density: 0)
}
