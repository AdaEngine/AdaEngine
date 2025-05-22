//
//  SystemQuery.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// A protocol for system queries.
public protocol SystemQuery: Sendable {
    /// Updates the query with the given world.
    func update(from world: World)
}

public extension SystemQuery {
    func update(from world: World) {
        fatalError("Query should be implemented")
    }
}
