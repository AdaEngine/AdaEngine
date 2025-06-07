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
    @inline(__always)
    static func _queryTargetContains(in entity: Entity) -> Bool

    /// Create a new query target from an entity.
    /// - Parameter entity: The entity to create a query target from.
    /// - Returns: A new query target.
    @inline(__always)
    static func _queryTarget(from entity: Entity) -> Self

    /// Check if an archetype contains the target.
    /// - Parameter archetype: The archetype to check.
    /// - Returns: True if the archetype contains the target, otherwise false.
    @inline(__always)
    static func _queryContains(in archetype: Archetype) -> Bool
}

extension Component {
    @inline(__always)
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        return entity.components.has(Self.self)
    }

    @inline(__always)
    public static func _queryTarget(from entity: Entity) -> Self {
        return entity.components.get(by: Self.identifier)!
    }

    @inline(__always)
    public static func _queryContains(in archetype: Archetype) -> Bool {
        archetype.componentsBitMask.contains(Self.identifier)
    }
}

extension Ref: QueryTarget where T: Component {

    @inline(__always)
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        T._queryTargetContains(in: entity)
    }

    @inline(__always)
    public static func _queryTarget(from entity: Entity) -> Ref<T> {
        Ref { [unowned entity] in
            return entity.components.get(T.self) as! T
        } set: { [entity] in
            entity.components.set($0)
        }
    }

    @inline(__always)
    public static func _queryContains(in archetype: Archetype) -> Bool {
        return archetype.componentsBitMask.contains(T.identifier)
    }
}

extension Entity: QueryTarget {

    @inline(__always)
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        return true
    }

    @inline(__always)
    public static func _queryTarget(from entity: Entity) -> Self {
        return entity as! Self
    }
    
    /// Always returns true because entity is always present in an archetype.
    @inline(__always)
    public static func _queryContains(in archetype: Archetype) -> Bool {
        return true
    }
}

extension Optional: QueryTarget where Wrapped: QueryTarget {
    @inline(__always)
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        Wrapped._queryTargetContains(in: entity)
    }

    @inline(__always)
    public static func _queryTarget(from entity: Entity) -> Self {
        if Wrapped._queryTargetContains(in: entity) {
            return .some(Wrapped._queryTarget(from: entity))
        }
        
        return .none
    }
    
    /// Always returns true because optional can be nil.
    @inline(__always)
    public static func _queryContains(in archetype: Archetype) -> Bool {
        return true
    }
}
