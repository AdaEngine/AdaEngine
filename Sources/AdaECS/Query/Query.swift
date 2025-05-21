//
//  Query.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/21/25.
//

public protocol SystemQuery: Sendable {
    func update(from world: World)
}

public extension SystemQuery {
    func update(from world: World) {
        fatalError("Query should be implemented")
    }
}
