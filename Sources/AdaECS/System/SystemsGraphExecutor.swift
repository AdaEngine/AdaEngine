//
//  SystemsGraphExecutor.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/24/23.
//

import AdaUtils
import Collections

protocol SystemsGraphExecutor: Sendable {

    mutating func initialize(_ graph: borrowing SystemsGraph)

    mutating func execute(
        _ graph: borrowing SystemsGraph,
        world: World,
        scheduler: SchedulerName
    ) async
}

/// The executor of the systems graph.
public struct SingleThreadedSystemsGraphExecutor: SystemsGraphExecutor {

    var systems: [any System] = []

    /// Initialize a new systems graph executor.
    public init() {}

    public mutating func initialize(_ graph: borrowing SystemsGraph) {
        systems = graph.systems
    }
    
    /// Execute the systems graph.
    /// - Parameter graph: The systems graph to execute.
    /// - Parameter world: The world to execute the systems graph in.
    /// - Parameter deltaTime: The delta time to execute the systems graph with.
    /// - Parameter scheduler: The scheduler to execute the systems graph on.
    public mutating func execute(
        _ graph: borrowing SystemsGraph,
        world: World,
        scheduler: SchedulerName
    ) async {
        for system in systems {
            await executeSystem(system: system, world: world, scheduler: scheduler)
            world.flush()
        }
    }

    private func executeSystem(
        system: any System,
        world: World,
        scheduler: SchedulerName
    ) async {
        system.queries.update(from: world)
        var context = WorldUpdateContext(
            world: world,
            scheduler: scheduler
        )

        await system.update(context: &context)
        _ = consume context
    }
}

