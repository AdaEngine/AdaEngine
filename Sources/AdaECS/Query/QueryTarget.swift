//
//  QueryTarget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

/// A protocol that allows to use components and entities as query targets.
public protocol QueryTarget: Sendable, ~Copyable {

    /// Check that entity contains target.
    /// - Parameter entity: The entity to check.
    /// - Returns: True if the entity contains the target, otherwise false.
    static func _queryTargetContains(in entity: Entity) -> Bool

    /// Create a new query target from an entity.
    /// - Parameter entity: The entity to create a query target from.
    /// - Returns: A new query target.
    static func _queryTarget(from entity: Entity) -> Self

    /// Check if an archetype contains the target.
    /// - Parameter archetype: The archetype to check.
    /// - Returns: True if the archetype contains the target, otherwise false.
    static func _queryContains(in archetype: Archetype) -> Bool
}

extension Component {
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        return entity.components.has(Self.self)
    }
    
    public static func _queryTarget(from entity: Entity) -> Self {
        return entity.components.get(by: Self.identifier)!
    }
    
    public static func _queryContains(in archetype: Archetype) -> Bool {
        archetype.componentsBitMask.contains(Self.identifier)
    }
}

extension Ref: QueryTarget where T: Component {
    
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        T._queryTargetContains(in: entity)
    }
    
    public static func _queryTarget(from entity: Entity) -> Ref<T> {
        Ref { [unowned entity] in
            return entity.components.get(T.self) as! T
        } set: { [unowned entity] in
            entity.components.set($0)
        }
    }
    
    public static func _queryContains(in archetype: Archetype) -> Bool {
        return archetype.componentsBitMask.contains(T.identifier)
    }
}

extension Entity: QueryTarget {
    
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        return true
    }
    
    public static func _queryTarget(from entity: Entity) -> Self {
        return entity as! Self
    }
    
    /// Always returns true because entity is always present in an archetype.
    public static func _queryContains(in archetype: Archetype) -> Bool {
        return true
    }
}

extension Optional: QueryTarget where Wrapped: QueryTarget {
    
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        Wrapped._queryTargetContains(in: entity)
    }
    
    public static func _queryTarget(from entity: Entity) -> Self {
        if Wrapped._queryTargetContains(in: entity) {
            return .some(Wrapped._queryTarget(from: entity))
        }
        
        return .none
    }
    
    /// Always returns true because optional can be nil.
    public static func _queryContains(in archetype: Archetype) -> Bool {
        return true
    }
}
