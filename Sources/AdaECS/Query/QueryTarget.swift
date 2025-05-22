//
//  QueryTarget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

/// A protocol that allows to use components and entities as query targets.
public protocol QueryTarget: Sendable {
    /// Create a new query target from an entity.
    static func _queryTarget(from entity: Entity) -> Self

    /// Check if an archetype contains the target.
    static func _queryContains(in archetype: Archetype) -> Bool
}

extension Component {
    public static func _queryTarget(from entity: Entity) -> Self {
        return entity.components.get(by: Self.identifier)
    }
    
    public static func _queryContains(in archetype: Archetype) -> Bool {
        archetype.componentsBitMask.contains(Self.identifier)
    }
}

extension Ref: QueryTarget {
    public static func _queryTarget(from entity: Entity) -> Ref<T> {
        Ref {
            entity.components.get(T.self)
        } set: {
            entity.components.set($0)
        }
    }
    
    public static func _queryContains(in archetype: Archetype) -> Bool {
        return archetype.componentsBitMask.contains(T.identifier)
    }
}

extension Entity: QueryTarget {
    public static func _queryTarget(from entity: Entity) -> Self {
        return entity as! Self
    }
    
    public static func _queryContains(in archetype: Archetype) -> Bool {
        return true
    }
}
