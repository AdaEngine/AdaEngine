//
//  QueryBuilder.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// A protocol for building queries.
public protocol QueryBuilder {
    associatedtype Components
    associatedtype ComponentTypes

    static func predicate(in archetype: Archetype) -> Bool

    static func getQueryTarget(from entity: Entity) -> Components
}

/// A type-erased query builder.
public struct QueryBuilderTargets<each T, F: Filter>: QueryBuilder where repeat each T: QueryTarget {
    public typealias ComponentTypes = (repeat (each T).Type)
    public typealias Components = (repeat each T)

    public static func predicate(in archetype: Archetype) -> Bool {
        for element in repeat (each T).self {
            if !element._queryContains(in: archetype) && F.condition(for: archetype) {
                return false
            }
        }

        return true
    }

    public static func getQueryTarget(from entity: Entity) -> Components {
        (repeat (each T)._queryTarget(from: entity))
    }
}
