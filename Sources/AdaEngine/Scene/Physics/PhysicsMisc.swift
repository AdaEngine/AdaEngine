//
//  PhysicsMisc.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

@frozen
public enum PhysicsBodyMode: Codable {
    case `static`
    case `dynamic`
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
    
    public static var `default` = CollisionGroup(rawValue: .max)
}
