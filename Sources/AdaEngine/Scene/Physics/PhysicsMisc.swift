//
//  PhysicsMisc.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

@frozen
public enum PhysicsBodyMode: Codable {
    /// Zero mass, zero velocity, may be manually moved
    case `static`
    /// Positive mass, non-zero velocity determined by forces, moved by solver
    case `dynamic`
    /// Zero mass, non-zero velocity set by user, moved by solver
    case kinematic
}

public struct CollisionFilter: Codable {
    public var categoryBitMask: CollisionGroup = .default
    public var collisionBitMask: CollisionGroup = .default
    
    public init(
        categoryBitMask: CollisionGroup = .default,
        collisionBitMask: CollisionGroup = .default
    ) {
        self.categoryBitMask = categoryBitMask
        self.collisionBitMask = collisionBitMask
    }
}

public struct CollisionGroup: OptionSet, Codable {
    public var rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    public static let `default` = CollisionGroup(rawValue: 1)
    public static let all = CollisionGroup(rawValue: .max)
}
