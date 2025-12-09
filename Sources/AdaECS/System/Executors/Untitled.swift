//
//  Untitled.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.11.2025.
//

import Collections

struct MultithreadedGraphExecutor: SystemsGraphExecutor {
    func initialize(
        _ graph: borrowing SystemsGraph
    ) {

    }
    
    func execute(
        _ graph: borrowing SystemsGraph,
        world: World,
        scheduler: SchedulerName
    ) async {

    }
}

public struct SystemFilterAccess: Sendable {
    public var access: BitSet
    public var denied: BitSet
}
