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

    /// The component fetches of the query builder.
    associatedtype ComponentsFetches

    /// The component states of the query builder.
    associatedtype ComponentsStates

    static func initState(world: World) -> ComponentsStates

    static func setChunk(
        states: ComponentsStates,
        fetches: inout ComponentsFetches,
        chunk: borrowing Chunk,
        archetype: borrowing Archetype
    )

    static func initFetches(
        world: World,
        states: ComponentsStates,
        lastTick: Tick
    ) -> ComponentsFetches
}

/// A protocol for building target queries.
public protocol QuertyTargetBuilder: QueryBuilder {
    static func getQueryTargets(
        for entity: Entity,
        states: ComponentsStates,
        fetches: ComponentsFetches,
        at row: Int
    ) -> Components?

    /// Predicate for the query builder.
    /// - Parameter archetype: The archetype to check.
    /// - Returns: True if the archetype satisfies the predicate, otherwise false.
    static func predicate(in archetype: borrowing Archetype) -> Bool
}

/// A protocol for building filter queries.
public protocol FilterTargetBuilder: QueryBuilder {
    static func condition(
        states: ComponentsStates,
        fetches: ComponentsFetches,
        at row: Int
    ) -> Bool
}

@usableFromInline
enum QueryBuilderTargetsError: Swift.Error {
    case failedToFetch
}

/// A type-erased query builder.
public struct QueryBuilderTargets<each T>: QueryBuilder where repeat each T: WorldQueryTarget {
    public typealias ComponentTypes = (repeat (each T).Type)
    public typealias Components = (repeat each T)
    public typealias ComponentsFetches = (repeat (each T).Fetch)
    public typealias ComponentsStates = (repeat (each T).State)

    @inlinable
    @inline(__always)
    public static func initState(world: World) -> ComponentsStates {
        (repeat (each T)._initState(world: world))
    }

    @inlinable
    @inline(__always)
    public static func initFetches(
        world: World,
        states: ComponentsStates,
        lastTick: Tick
    ) -> ComponentsFetches {
        return (repeat (each T)._initFetch(
            world: world,
            state: each states,
            lastTick: lastTick,
            currentTick: world.currentTick
        ))
    }

    @inlinable
    @inline(__always)
    public static func setChunk(
        states: ComponentsStates,
        fetches: inout ComponentsFetches,
        chunk: borrowing Chunk,
        archetype: borrowing Archetype
    ) {
        fetches = (repeat (each T)._setData(
            state: each states,
            fetch: each fetches,
            chunk: chunk,
            archetype: archetype
        ))
    }
}

extension QueryBuilderTargets: QuertyTargetBuilder where repeat each T: QueryTarget {
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
    public static func getQueryTargets(
        for entity: Entity,
        states: ComponentsStates,
        fetches: ComponentsFetches,
        at row: Int
    ) -> Components? {
        @inline(__always)
        func fetch<Q: QueryTarget>(_ type: Q.Type, state: Q.State, fetch: Q.Fetch) throws -> Q {
            guard let value = Q._queryFetch(for: entity, state: state, fetch: fetch, at: row) else {
                throw QueryBuilderTargetsError.failedToFetch
            }
            return value
        }
        do {
            return try (repeat fetch((each T).self, state: each states, fetch: each fetches))
        } catch {
            return nil
        }
    }
}

extension QueryBuilderTargets: FilterTargetBuilder where repeat each T: Filter {
    @inlinable
    @inline(__always)
    public static func condition(
        states: ComponentsStates,
        fetches: ComponentsFetches,
        at row: Int
    ) -> Bool {
        for (filter, state, fetch) in repeat ((each T).self, each states, each fetches) {
            if !filter.condition(state: state, fetch: fetch, at: row) {
                return false
            }
        }
        return true
    }
}
