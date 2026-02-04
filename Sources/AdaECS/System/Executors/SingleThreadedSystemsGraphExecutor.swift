//
//  SingleThreadedSystemsGraphExecutor.swift
//  AdaEngine
//

import AdaUtils
import Collections

/// The executor of the systems graph.
public struct SingleThreadedSystemsGraphExecutor: SystemsGraphExecutor {

    private var nodes: Deque<SystemsGraph.Node> = []

    /// Initialize a new systems graph executor.
    public init() {}

    public mutating func initialize(_ graph: borrowing SystemsGraph) {
        let values = graph.nodes.filter { $0.inputEdges.isEmpty }
        self.nodes = Deque(values)
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
        var completedSystems: Set<String> = []
        var nodes = nodes
    nextNode:
        while let currentNode = nodes.popLast() {
            // if we has a outputs for node we should skip it
            if completedSystems.contains(currentNode.name) {
                continue
            }

            for inputNode in graph.getInputNodes(for: currentNode.name) {
                if !completedSystems.contains(inputNode.name) {
                    nodes.prepend(currentNode)
                    continue nextNode
                }
            }

            await executeSystem(
                system: currentNode,
                world: world,
                scheduler: scheduler
            )
            completedSystems.insert(currentNode.name)

            for outputNode in graph.getOuputNodes(for: currentNode.name) {
                nodes.prepend(outputNode)
            }
        }
    }

    @concurrent
    private func executeSystem(
        system: SystemsGraph.Node,
        world: World,
        scheduler: SchedulerName
    ) async {
        await AdaTrace.span("System.execute.\(system.name)") {
            system.queries.update(from: world)
            await system.system.update(
                context: WorldUpdateContext(
                    world: world,
                    scheduler: scheduler
                )
            )
            // TODO: I don't like that sync point
            await system.queries.finish(world)
            world.flush()
        }
    }
}
