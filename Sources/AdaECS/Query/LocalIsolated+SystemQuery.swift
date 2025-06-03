//
//  LocalIsolated+SystemQuery.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.06.2025.
//

import AdaUtils

extension LocalIsolated: SystemQuery {

    convenience public init(from world: World) {
        fatalError("Can't be initialized from world")
    }

    /// Updates the query state with the given world.
    public func update(from world: consuming World) {

    }
}
