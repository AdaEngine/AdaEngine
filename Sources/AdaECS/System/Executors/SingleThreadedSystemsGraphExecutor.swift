//
//  SingleThreadedSystemsGraphExecutor.swift
//  AdaEngine
//

import AdaUtils
import Collections

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
            await executeSystem(
                system: system,
                world: world,
                scheduler: scheduler
            )
            world.flush()
        }
    }

    @concurrent
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
        // TODO: I don't like that sync point
        await system.queries.finish(world)
        _ = consume context
    }
}

