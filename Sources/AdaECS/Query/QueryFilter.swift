//
//  QueryFilter.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// Filter for entity query.
public struct QueryFilter: OptionSet, Sendable {
    /// The raw value of the query filter.
    public typealias RawValue = UInt8

    /// The raw value of the query filter.
    public var rawValue: UInt8

    /// Initialize a new query filter.
    /// - Parameter rawValue: The raw value of the query filter.
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Returns entities which added to world.
    public static let added = QueryFilter(rawValue: 1 << 0)

    /// Returns entities which stored in world.
    public static let stored = QueryFilter(rawValue: 1 << 1)

    /// Returns entities which wait removing from world.
    public static let removed = QueryFilter(rawValue: 1 << 2)

    /// Filter that include all values.
    public static let all: QueryFilter = [.added, .stored, .removed]
}

/// A protocol for filters.
public protocol Filter: Sendable {

    /// Check if the filter is satisfied for an archetype.
    /// - Parameter archetype: The archetype to check.
    /// - Returns: True if the filter is satisfied for the archetype, otherwise false.
    static func condition(
        for archetype: Archetype,
        in chunk: borrowing Chunk,
        entity: Entity,
        lastTick: Tick
    ) -> Bool
}

/// A filter that includes entities with a specific component.
public struct With<T: Component>: Filter {
    public static func condition(
        for archetype: Archetype,
        in chunk: borrowing Chunk,
        entity: Entity,
        lastTick: Tick
    ) -> Bool {
        archetype.componentLayout.bitSet.contains(T.self)
    }
}

/// A filter that excludes entities with a specific component.
public struct Without<T: Component>: Filter {
    public static func condition(
        for archetype: Archetype,
        in chunk: borrowing Chunk,
        entity: Entity,
        lastTick: Tick
    ) -> Bool {
        !archetype.componentLayout.bitSet.contains(T.self)
    }
}

/// A filter that combines two filters with a logical AND operation.
public struct And<each T: Filter>: Filter {
    public static func condition(
        for archetype: Archetype,
        in chunk: borrowing Chunk,
        entity: Entity,
        lastTick: Tick
    ) -> Bool {
        for element in repeat (each T).self {
            if !element.condition(
                for: archetype,
                in: chunk,
                entity: entity,
                lastTick: lastTick
            ) {
                return false
            }
        }
        return true
    }
}

public struct Not<T: Filter>: Filter {
    public static func condition(
        for archetype: Archetype,
        in chunk: borrowing Chunk,
        entity: Entity,
        lastTick: Tick
    ) -> Bool {
        !T.condition(for: archetype, in: chunk, entity: entity, lastTick: lastTick)
    }
}

/// A filter that combines two filters with a logical OR operation.
public struct Or<each T: Filter>: Filter {
    public static func condition(
        for archetype: Archetype,
        in chunk: borrowing Chunk,
        entity: Entity,
        lastTick: Tick
    ) -> Bool {
        for element in repeat (each T).self {
            if element.condition(
                for: archetype,
                in: chunk,
                entity: entity,
                lastTick: lastTick
            ) {
                return true
            }
        }
        return false
    }
}

public struct Changed<T: Component>: Filter {
    public static func condition(
        for archetype: Archetype,
        in chunk: borrowing Chunk,
        entity: Entity,
        lastTick: Tick
    ) -> Bool {
        chunk.isComponentChanged(T.self, for: entity.id, lastTick: lastTick)
    }
}

/// A filter that includes all entities.
public struct NoFilter: Filter {
    public static func condition(
        for archetype: Archetype,
        in chunk: borrowing Chunk,
        entity: Entity,
        lastTick: Tick
    ) -> Bool {
        true
    }
}
