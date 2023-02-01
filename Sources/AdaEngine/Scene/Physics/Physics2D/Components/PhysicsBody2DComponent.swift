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
    
    /// Get the world position of the center of mass.
    /// - Returns: World position of the center of mass or zero if entity not connected to physics world.
    public var worldCenter: Vector2 {
        self.runtimeBody?.ref.worldCenter.asVector2 ?? .zero
    }
    
    /// Linear velocity of the center of mass.
    /// - Returns: The linear velocity of the center of mass or zero if entity not connected to physics world.
    public var linearVelocity: Vector2 {
        self.runtimeBody?.ref.linearVelocity.asVector2 ?? .zero
    }
    
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
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case mode
        case filter
        case shapes
        case material
        case massProperties
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(CollisionFilter.self, forKey: .filter)
        self.mode = try container.decode(PhysicsBodyMode.self, forKey: .mode)
        self.shapes = try container.decode([Shape2DResource].self, forKey: .shapes)
        self.material = try container.decode(PhysicsMaterial.self, forKey: .material)
        self.massProperties = try container.decode(PhysicsMassProperties.self, forKey: .massProperties)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.shapes, forKey: .shapes)
        try container.encode(self.mode, forKey: .mode)
        try container.encode(self.filter, forKey: .filter)
        try container.encode(self.material, forKey: .material)
        try container.encode(self.massProperties, forKey: .massProperties)
    }
    
    // MARK: - Methods
    
    /// Set the position of the body’s origin and rotation. Manipulating a body’s transform may cause non-physical behavior.
    /// - Note: Contacts are updated on the next call to of Physics2DWorld.
    public func setPosition(_ position: Vector2, angle: Angle? = nil) {
        guard let body = self.runtimeBody?.ref else { return }
        body.setTransform(position: position.b2Vec, angle: angle?.radians ?? body.angle)
    }
    
    /// Set the linear velocity of the center of mass.
    public func setLinearVelocity(_ vector: Vector2) {
        self.runtimeBody?.ref.setLinearVelocity(vector.b2Vec)
    }
    
    /// Apply a force at a world point. If the force is not applied at the center of mass, it will generate a torque and affect the angular velocity. This wakes up the body.
    public func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyForce(force.b2Vec, point: point.b2Vec, wake: wake)
    }
    
    /// Apply a force to the center of mass. This wakes up the body.
    public func applyForceToCenter(_ force: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyForceToCenter(force.b2Vec, wake: wake)
    }
    
    /// Apply an impulse at a point. This immediately modifies the velocity.
    /// It also modifies the angular velocity if the point of application is not at the center of mass. This wakes up the body.
    public func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
        self.runtimeBody?.ref.applyLinearImpulse(impulse.b2Vec, point: point.b2Vec, wake: wake)
    }
    
    /// Apply a torque. This affects the angular velocity without affecting the linear velocity of the center of mass. This wakes up the body.
    public func applyTorque(_ torque: Float, wake: Bool) {
        self.runtimeBody?.ref.applyTorque(torque, wake: wake)
    }
    
    /// Get the world linear velocity of a world point attached to this body.
    /// - Parameter worldPoint: point in world coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    public func getLinearVelocityFromWorldPoint(_ worldPoint: Vector2) -> Vector2 {
        self.runtimeBody?.ref.getLinearVelocityFromWorldPoint(worldPoint.b2Vec).asVector2 ?? .zero
    }
    
    /// Get the world velocity of a local point.
    /// - Parameter localPoint: point in local coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    public func getLinearVelocityFromLocalPoint(_ localPoint: Vector2) -> Vector2 {
        self.runtimeBody?.ref.getLinearVelocityFromLocalPoint(localPoint.b2Vec).asVector2 ?? .zero
    }
}
