//
//  QueryBuilder.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// A protocol for building queries.
public protocol QueryBuilder: Sendable {

    /// The components of the query builder.
    associatedtype Components

    /// The component types of the query builder.
    associatedtype ComponentTypes

    /// Predicate for the query builder.
    /// - Parameter archetype: The archetype to check.
    /// - Returns: True if the archetype satisfies the predicate, otherwise false.
    static func predicate(in archetype: borrowing Archetype) -> Bool

    /// Get the query target from an entity.
    /// - Parameter entity: The entity to get the query target from.
    /// - Returns: The query target.
    static func getQueryTarget(
        for entity: Entity,
        in chunk: borrowing Chunk,
        archetype: borrowing Archetype,
        world: borrowing World
    ) -> Components
}

/// A type-erased query builder.
public struct QueryBuilderTargets<each T>: QueryBuilder where repeat each T: QueryTarget {
    public typealias ComponentTypes = (repeat (each T).Type)
    public typealias Components = (repeat each T)

    @inlinable
    @inline(__always)
    public static func predicate(in archetype: Archetype) -> Bool {
        for element in repeat (each T).self {
            if !element._queryContains(in: archetype) {
                return false
            }
        }

        return true
    }

    @inlinable
    @inline(__always)
    public static func getQueryTarget(
        for entity: Entity,
        in chunk: borrowing Chunk,
        archetype: Archetype,
        world: borrowing World
    ) -> Components {
        (repeat (each T)._queryTarget(for: entity, in: chunk, archetype: archetype, world: world))
    }
}
