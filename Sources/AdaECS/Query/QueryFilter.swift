//
//  QueryFilter.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// Filter for entity query.
public struct QueryFilter: OptionSet, Sendable {
    public typealias RawValue = UInt8

    public var rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Returns entities which added to world.
    public static let added = QueryFilter(rawValue: 1 << 0)

    /// Returns entities which stored in world.
    public static let stored = QueryFilter(rawValue: 1 << 1)

    /// Returns entities which wait removing from world.
    public static let removed = QueryFilter(rawValue: 1 << 2)

    /// Filter that include all values
    public static let all: QueryFilter = [.added, .stored, .removed]
}

public protocol Filter: Sendable {
    static func condition(for archetype: Archetype) -> Bool
}

public struct With<T: Component>: Filter {
    public static func condition(for archetype: Archetype) -> Bool {
        archetype.componentsBitMask.contains(T.self)
    }
}

public struct WithOut<T: Component>: Filter {
    public static func condition(for archetype: Archetype) -> Bool {
        !archetype.componentsBitMask.contains(T.self)
    }
}

public struct And<T: Filter, U: Filter>: Filter {
    public static func condition(for archetype: Archetype) -> Bool {
        T.condition(for: archetype) && U.condition(for: archetype)
    }
}

public struct Or<T: Filter, U: Filter>: Filter {
    public static func condition(for archetype: Archetype) -> Bool {
        T.condition(for: archetype) || U.condition(for: archetype)
    }
}