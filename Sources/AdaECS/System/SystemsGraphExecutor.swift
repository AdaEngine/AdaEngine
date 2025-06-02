//
//  SystemsGraphExecutor.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/24/23.
//

import AdaUtils
import Collections

// TOOD: Parallel execution for non dependent values

/// The executor of the systems graph.
public struct SystemsGraphExecutor: Sendable {

    /// Initialize a new systems graph executor.
    public init() {}
    
    /// Execute the systems graph.
    /// - Parameter graph: The systems graph to execute.
    /// - Parameter world: The world to execute the systems graph in.
    /// - Parameter deltaTime: The delta time to execute the systems graph with.
    /// - Parameter scheduler: The scheduler to execute the systems graph on.
    public func execute(
        _ graph: borrowing SystemsGraph,
        world: World,
        deltaTime: AdaUtils.TimeInterval,
        scheduler: SchedulerName
    ) async {
        var completedSystems: Set<String> = []
        completedSystems.reserveCapacity(graph.nodes.count)
        
        let values = graph.nodes.values.elements.filter { $0.inputEdges.isEmpty }
        var nodes: Deque<SystemsGraph.Node> = Deque(values)
        
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
            
            currentNode.system.queries.update(from: world)

            await withTaskGroup(of: Void.self) { @MainActor group in
                var context = WorldUpdateContext(
                    world: world,
                    deltaTime: deltaTime,
                    scheduler: scheduler,
                    taskGroup: group
                )
                
                currentNode.system.update(context: &context)
                _ = consume context
            }
            world.flush()
            completedSystems.insert(currentNode.name)
            
            for outputNode in graph.getOuputNodes(for: currentNode.name) {
                nodes.prepend(outputNode)
            }
        }
    }
}
