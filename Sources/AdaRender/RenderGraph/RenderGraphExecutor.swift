//
//  RenderGraphExecutor.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/18/23.
//

// Inspired by Bevy https://github.com/bevyengine/bevy/tree/main/crates/bevy_render/src/render_graph

import AdaECS
import AdaUtils
import Logging
import Collections
import Tracing

/// Execute ``RenderGraph`` objects.
public struct RenderGraphExecutor: Sendable {

    public init() {}

    /// Execute ``RenderGraph`` for specific ``World``.
    public func execute(
        _ graph: RenderGraph,
        renderDevice: RenderDevice,
        in world: World
    ) async throws {
        let renderContext = RenderContext(device: renderDevice, commandQueue: renderDevice.createCommandQueue())
        try await self.executeGraph(
            graph,
            renderContext: renderContext,
            world: world,
            inputResources: [],
            viewEntity: nil
        )
    }
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func executeGraph(
        _ graph: RenderGraph,
        renderContext: RenderContext,
        world: World,
        inputResources: [RenderSlotValue],
        viewEntity: Entity?
    ) async throws {
        let span = AdaTrace.startSpan("RenderGraph.frame.\(graph.label?.rawValue ?? "Unknown")")
        defer {
            span.end()
        }
        let tracer = Logger(label: "RenderGraph")
        tracer.trace("Begin Render Graph Frame", metadata: [
            "graph": .string(graph.label?.rawValue ?? "Unknown")
        ])

        var writtenResources = [RenderGraph.Node.ID: [RenderSlotValue]]()
        
        /// Should execute firsts
        var nodes: Deque<RenderGraph.Node> = Deque(graph.nodes.filter { $0.value.inputEdges.isEmpty }.values)
        
        if let entryNode = graph.entryNode {
            for (index, inputSlot) in entryNode.node.inputResources.enumerated() {
                let resource = inputResources[index]
                
                if resource.value.resourceKind != inputSlot.kind {
                    assertionFailure("Mismatched slot type for resource kind \(resource.value.resourceKind), and input \(inputSlot.kind)")
                    tracer.error("Mismatched slot type", metadata: [
                        "graph": .string(graph.label?.rawValue ?? "Unknown"),
                        "resourceName": .string(resource.name.rawValue),
                        "resourceKind": .string(resource.value.resourceKind.rawValue),
                        "inputSlotName": .string(inputSlot.name.rawValue),
                        "inputSlotKind": .string(inputSlot.kind.rawValue)
                    ])
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
            var context = RenderGraphContext(
                graph: graph,
                world: world,
                inputResources: inputs,
                tracer: tracer,
                viewEntity: viewEntity
            )
            let outputs = try await currentNode.node.execute(context: &context, renderContext: renderContext)
            for subGraph in context.pendingSubgraphs {
                try await self.executeGraph(
                    subGraph.graph,
                    renderContext: renderContext,
                    world: world,
                    inputResources: subGraph.inputs,
                    viewEntity: subGraph.viewEntity
                )
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
