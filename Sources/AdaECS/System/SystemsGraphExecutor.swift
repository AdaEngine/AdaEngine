//
//  SystemsGraphExecutor.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/24/23.
//

import AdaUtils
import Collections

struct SystemsGraphExecutor: Sendable {
    public init() {}
    
    func execute(
        _ graph: SystemsGraph,
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
                let context = WorldUpdateContext(
                    world: world,
                    deltaTime: deltaTime,
                    scheduler: scheduler,
                    taskGroup: group
                )
                
                currentNode.system.update(context: context)
            }
            world.flush()
            completedSystems.insert(currentNode.name)
            
            for outputNode in graph.getOuputNodes(for: currentNode.name) {
                nodes.prepend(outputNode)
            }
        }
    }
}
