//
//  PhysicsBody2DComponent.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

import Math

public struct PhysicsBody2DComponent: Component {
    
    public var mode: PhysicsBodyMode
    public var filter: CollisionFilter = CollisionFilter()
    
    internal var runtimeBody: Body2D?
    public var shapes: [Shape2DResource]
    public var material: PhysicsMaterial
    public var massProperties: PhysicsMassProperties
    
    public init(
        shapes: [Shape2DResource],
        massProperties: PhysicsMassProperties,
        material: PhysicsMaterial? = nil,
        mode: PhysicsBodyMode = .dynamic
    ) {
        self.mode = mode
        self.shapes = shapes
        self.massProperties = massProperties
        self.material = material ?? .default
    }
    
    public init(
        shapes: [Shape2DResource],
        mass: Float,
        material: PhysicsMaterial? = nil,
        mode: PhysicsBodyMode = .dynamic
    ) {
        self.mode = mode
        self.shapes = shapes
        self.massProperties = PhysicsMassProperties(mass: mass, inertia: .zero)
        self.material = material ?? .default
    }
    
    // MARK: - Methods
    
    public func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyForce(force.b2Vec, point: point.b2Vec, wake: wake)
    }
    
    public func applyForceToCenter(_ force: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyForceToCenter(force.b2Vec, wake: wake)
    }
    
    public func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyLinearImpulse(impulse.b2Vec, point: point.b2Vec, wake: wake)
    }
    
    public func applyTorque(_ torque: Float, wake: Bool) {
        self.runtimeBody?.ref.applyTorque(torque, wake: wake)
    }
}
