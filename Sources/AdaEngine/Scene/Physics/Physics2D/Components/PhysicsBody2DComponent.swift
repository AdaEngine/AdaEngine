//
//  PhysicsBody2DComponent.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

public struct PhysicsBody2DComponent: Component {
    
    public var mode: PhysicsBodyMode
    public var filter: CollisionFilter = CollisionFilter()
    
    internal var runtimeBody: Body2D?
    public var shapes: [Shape2DResource]
    public var density: Float
    public var mass: Float
    
    public init(shapes: [Shape2DResource], density: Float, mode: PhysicsBodyMode = .dynamic) {
        self.mode = mode
        self.shapes = shapes
        self.density = density
        self.mass = 0
    }
    
    public init(shapes: [Shape2DResource], mass: Float, mode: PhysicsBodyMode = .dynamic) {
        self.mode = mode
        self.shapes = shapes
        self.density = 0
        self.mass = mass
    }
    
    public func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyForce(force.b2Vec, point: point.b2Vec, wake: wake)
    }
    
    public func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyLinearImpulse(impulse.b2Vec, point: point.b2Vec, wake: wake)
    }
}
