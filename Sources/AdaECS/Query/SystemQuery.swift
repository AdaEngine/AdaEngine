//
//  SystemQuery.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// A protocol that describe a query for world from a system.
public protocol SystemQuery: Sendable {

    /// Initialize a new system query.
    /// - Parameter world: The world that will be used to initialize the query.
    init(from world: World)

    /// Updates the query state with the given world.
    /// - Parameter world: The world that will be used to update the query.
    /// Updates the query state with the given world.
    func update(from world: consuming World)
}

public extension SystemQuery {
    func update(from world: consuming World) {
        fatalError("Query should be implemented")
    }
}
