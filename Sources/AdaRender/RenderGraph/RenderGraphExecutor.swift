//
//  RenderGraphExecutor.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/18/23.
//

// Inspired by Bevy https://github.com/bevyengine/bevy/tree/main/crates/bevy_render/src/render_graph

import AdaECS
import Logging
import Collections

/// Execute ``RenderGraph`` objects.
@RenderGraphActor
public class RenderGraphExecutor {

    public nonisolated init() {}

    /// Execute ``RenderGraph`` for specific ``World``.
    public func execute(_ graph: RenderGraph, in world: World) async throws {
        try await self.executeGraph(graph, world: world, inputResources: [], viewEntity: nil)
    }
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func executeGraph(_ graph: RenderGraph, world: World, inputResources: [RenderSlotValue], viewEntity: Entity?) async throws {
        let tracer = Logger(label: "RenderGraph")
        tracer.trace("Begin Render Graph Frame")

        var writtenResources = [RenderGraph.Node.ID: [RenderSlotValue]]()
        
        /// Should execute firsts
        var nodes: Deque<RenderGraph.Node> = Deque(graph.nodes.filter { $0.value.inputEdges.isEmpty }.values)
        
        if let entryNode = graph.entryNode {
            for (index, inputSlot) in entryNode.node.inputResources.enumerated() {
                let resource = inputResources[index]
                
                if resource.value.resourceKind != inputSlot.kind {
                    fatalError("Mismatched slot type")
                }
            }
            
            writtenResources[entryNode.name] = inputResources
            
            for (_, node) in graph.getOutputNodes(for: entryNode.name) {
                nodes.prepend(node)
            }
        }
    nextNode:
        while let currentNode = nodes.popLast() {
            // if we has a outputs for node we should skip it
            if writtenResources[currentNode.name] != nil {
                continue
            }
            
            var inputSlots: [(Int, RenderSlotValue)] = []
            
            for (edge, inputNode) in graph.getInputNodes(for: currentNode.name) {
                switch edge {
                case .slot(_, let outputSlotIndex, _, let inputSlotIndex):
                    if let outputs = writtenResources[inputNode.name] {
                        inputSlots.append(
                            (
                                inputSlotIndex,
                                outputs[outputSlotIndex]
                            )
                        )
                    } else {
                        nodes.prepend(currentNode)
                        continue nextNode
                    }
                case .node:
                    if writtenResources[inputNode.name] == nil {
                        nodes.prepend(currentNode)
                        continue nextNode
                    }
                }
            }
            let inputs = inputSlots.sorted(by: { $0.0 > $1.0 }).map { $0.1 }
            let context = RenderGraphContext(
                graph: graph,
                world: world,
                device: RenderEngine.shared.renderDevice,
                inputResources: inputs,
                tracer: tracer,
                viewEntity: viewEntity
            )
            let outputs = try await currentNode.node.execute(context: context)
            for (subGraph, inputValues, viewEntity) in context.pendingSubgraphs {
                try await self.executeGraph(subGraph, world: world, inputResources: inputValues, viewEntity: viewEntity)
            }

            precondition(outputs.count == currentNode.node.outputResources.count)
            writtenResources[currentNode.name] = outputs

            for (_, outputNode) in graph.getOutputNodes(for: currentNode.name) {
                nodes.prepend(outputNode)
            }
        }

        tracer.trace("End Render Graph Frame")
    }
}
