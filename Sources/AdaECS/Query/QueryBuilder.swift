//
//  QueryBuilder.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// A protocol for building queries.
public protocol QueryBuilder {

    /// The components of the query builder.
    associatedtype Components

    /// The component types of the query builder.
    associatedtype ComponentTypes

    /// Predicate for the query builder.
    /// - Parameter archetype: The archetype to check.
    /// - Returns: True if the archetype satisfies the predicate, otherwise false.
    static func predicate(in archetype: Archetype) -> Bool

    /// Get the query target from an entity.
    /// - Parameter entity: The entity to get the query target from.
    /// - Returns: The query target.
    static func getQueryTarget(from entity: Entity) -> Components
}

/// A type-erased query builder.
public struct QueryBuilderTargets<each T, F: Filter>: QueryBuilder where repeat each T: QueryTarget {
    public typealias ComponentTypes = (repeat (each T).Type)
    public typealias Components = (repeat each T)

    public static func predicate(in archetype: Archetype) -> Bool {
        for element in repeat (each T).self {
            if !element._queryContains(in: archetype) {
                return false
            }
        }

        return F.condition(for: archetype)
    }

    public static func getQueryTarget(from entity: Entity) -> Components {
        (repeat (each T)._queryTarget(from: entity))
    }
}
