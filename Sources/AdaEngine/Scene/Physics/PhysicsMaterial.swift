//
//  PhysicsMaterial.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/12/22.
//

/// Material properties, like friction, of a physically simulated object.
final public class PhysicsMaterial: Codable {
    
    let friction: Float
    let restitution: Float
    let density: Float
    
    internal init(friction: Float, restitution: Float, density: Float) {
        self.friction = friction
        self.restitution = restitution
        self.density = density
    }
    
    /// Generates a new material with the given characteristics.
    public static func generate(friction: Float, restitution: Float, density: Float) -> PhysicsMaterial {
        return PhysicsMaterial(friction: friction, restitution: restitution, density: density)
    }
}

public extension PhysicsMaterial {
    
    /// A default material resource.
    static let `default` = PhysicsMaterial(friction: 0.2, restitution: 0, density: 0)
}
