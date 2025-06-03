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
    static func condition(for archetype: Archetype) -> Bool
}

/// A filter that includes entities with a specific component.
public struct With<T: Component>: Filter {
    public static func condition(for archetype: Archetype) -> Bool {
        archetype.componentsBitMask.contains(T.self)
    }
}

/// A filter that excludes entities with a specific component.
public struct WithOut<T: Component>: Filter {
    public static func condition(for archetype: Archetype) -> Bool {
        !archetype.componentsBitMask.contains(T.self)
    }
}

/// A filter that combines two filters with a logical AND operation.
public struct And<T: Filter, U: Filter>: Filter {
    public static func condition(for archetype: Archetype) -> Bool {
        T.condition(for: archetype) && U.condition(for: archetype)
    }
}

/// A filter that combines two filters with a logical OR operation.
public struct Or<T: Filter, U: Filter>: Filter {
    public static func condition(for archetype: Archetype) -> Bool {
        T.condition(for: archetype) || U.condition(for: archetype)
    }
}

/// A filter that includes all entities.
public struct NoFilter: Filter {
    public static func condition(for archetype: Archetype) -> Bool {
        true
    }
}
