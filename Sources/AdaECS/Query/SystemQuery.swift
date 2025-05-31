//
//  SystemQuery.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

/// A protocol for system queries.
public protocol SystemQuery: Sendable {

    init(from world: World)

    /// Updates the query state with the given world.
    func update(from world: World)
}

public extension SystemQuery {
    func update(from world: World) {
        fatalError("Query should be implemented")
    }
}
