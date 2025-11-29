//
//  QueryTarget.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 22.05.2025.
//

import AdaUtils

/// A protocol that allows to use components and entities as query targets.
public protocol QueryTarget: Sendable, ~Copyable {

    /// Check that entity contains target.
    /// - Parameter entity: The entity to check.
    /// - Returns: True if the entity contains the target, otherwise false.
    @inlinable
    static func _queryTargetContains(in entity: Entity) -> Bool

    /// Create a new query target from an entity.
    /// - Parameter entity: The entity to create a query target from.
    /// - Returns: A new query target.
    @inlinable
    static func _queryTarget(
        for entity: Entity,
        in chunk: borrowing Chunk,
        archetype: borrowing Archetype,
        world: borrowing World
    ) -> Self

    /// Check if an archetype contains the target.
    /// - Parameter archetype: The archetype to check.
    /// - Returns: True if the archetype contains the target, otherwise false.
    @inlinable
    static func _queryContains(in archetype: borrowing Archetype) -> Bool
}

extension Component {
    @inlinable
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        return entity.components.has(Self.self)
    }

    @inlinable
    public static func _queryTarget(
        for entity: Entity,
        in chunk: borrowing Chunk,
        archetype: borrowing Archetype,
        world: borrowing World
    ) -> Self {
        let value = chunk.get(Self.self, for: entity.id)
        assert(value != nil, "Value of type \(Self.self) in chunk \(chunk.description) for entity \(entity.id) not found")
        return value!
    }

    @inlinable
    public static func _queryContains(in archetype: borrowing Archetype) -> Bool {
        archetype.componentLayout.maskSet.contains(Self.identifier)
    }
}

extension Ref: QueryTarget where T: Component {

    @inlinable
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        T._queryTargetContains(in: entity)
    }

    @inlinable
    public static func _queryTarget(
        for entity: Entity,
        in chunk: borrowing Chunk,
        archetype: borrowing Archetype,
        world: borrowing World
    ) -> Ref<T> {
        unsafe Ref(
            pointer: chunk.getMutablePointer(T.self, for: entity.id)!,
            changeTick: .init(
                change: chunk.getMutableTick(T.self, for: entity.id)!.unsafeBox(),
                lastTick: world.lastTick,
                currentTick: world.lastTick
            )
        )
    }

    @inlinable
    public static func _queryContains(in archetype: borrowing Archetype) -> Bool {
        return archetype.componentLayout.maskSet.contains(T.identifier)
    }
}

extension Entity: QueryTarget {

    @inlinable
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        return true
    }

    @inlinable
    public static func _queryTarget(
        for entity: Entity,
        in chunk: borrowing Chunk,
        archetype: borrowing Archetype,
        world: borrowing World
    ) -> Self {
        return entity as! Self
    }
    
    /// Always returns true because entity is always present in an archetype.
    @inlinable
    public static func _queryContains(in archetype: borrowing Archetype) -> Bool {
        return true
    }
}

extension Optional: QueryTarget where Wrapped: QueryTarget {
    @inlinable
    public static func _queryTargetContains(in entity: Entity) -> Bool {
        Wrapped._queryTargetContains(in: entity)
    }

    @inlinable
    public static func _queryTarget(
        for entity: Entity,
        in chunk: borrowing Chunk,
        archetype: borrowing Archetype,
        world: borrowing World
    ) -> Self {
        if Wrapped._queryTargetContains(in: entity) {
            return .some(
                Wrapped._queryTarget(
                    for: entity,
                    in: chunk,
                    archetype: archetype,
                    world: world
                )
            )
        }
        
        return .none
    }

    @inlinable
    public static func _queryContains(in archetype: borrowing Archetype) -> Bool {
        return Wrapped._queryContains(in: archetype)
    }
}
