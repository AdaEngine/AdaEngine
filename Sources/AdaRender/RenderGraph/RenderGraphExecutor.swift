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
import DequeModule
import Foundation
import Tracing

/// Execute ``RenderGraph`` objects.
public struct RenderGraphExecutor: Sendable {

    public init() {}

    /// Execute ``RenderGraph`` for specific ``World``.
    public func execute(
        _ graph: RenderGraph,
        renderDevice: RenderDevice,
        in world: World,
        diagnostics: RenderGraphDiagnostics? = nil
    ) async throws {
        let renderContext = RenderContext(device: renderDevice, commandQueue: renderDevice.createCommandQueue())
        let diagnostics = diagnostics?.isEnabled == true ? diagnostics : nil
        try await self.executeGraph(
            graph,
            renderContext: renderContext,
            world: world,
            inputResources: [],
            viewEntity: nil,
            diagnostics: diagnostics,
            frameIndex: diagnostics?.makeFrameIndex(),
            isSubgraph: false
        )
    }
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func executeGraph(
        _ graph: RenderGraph,
        renderContext: RenderContext,
        world: World,
        inputResources: [RenderSlotValue],
        viewEntity: Entity?,
        diagnostics: RenderGraphDiagnostics?,
        frameIndex: Int?,
        isSubgraph: Bool
    ) async throws {
        let span = AdaTrace.startSpan("RenderGraph.frame.\(graph.label?.rawValue ?? "Unknown")")
        defer {
            span.end()
        }
        let graphStartedAt = Date()
        var executionOrder: [String] = []
        var nodeRecords: [RenderGraphNodeRecord] = []
        var pendingSubgraphLabels: [String] = []
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
        do {
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
                let nodeStartedAt = Date()
                executionOrder.append(currentNode.name.rawValue)
                do {
                    let outputs = try await currentNode.node.execute(context: &context, renderContext: renderContext)
                    let subgraphLabels = context.pendingSubgraphs.map { $0.graph.label?.rawValue ?? "RenderGraph" }
                    pendingSubgraphLabels.append(contentsOf: subgraphLabels)

                    nodeRecords.append(RenderGraphNodeRecord(
                        label: currentNode.name.rawValue,
                        typeName: String(reflecting: Swift.type(of: currentNode.node)),
                        inputResources: inputs.map { RenderResourceSummary(slotValue: $0) },
                        outputResources: outputs.map { RenderResourceSummary(slotValue: $0) },
                        pendingSubgraphs: subgraphLabels,
                        durationMilliseconds: Date().timeIntervalSince(nodeStartedAt) * 1000,
                        error: nil
                    ))

                    for subGraph in context.pendingSubgraphs {
                        try await self.executeGraph(
                            subGraph.graph,
                            renderContext: renderContext,
                            world: world,
                            inputResources: subGraph.inputs,
                            viewEntity: subGraph.viewEntity,
                            diagnostics: diagnostics,
                            frameIndex: frameIndex,
                            isSubgraph: true
                        )
                    }

                    precondition(outputs.count == currentNode.node.outputResources.count)
                    writtenResources[currentNode.name] = outputs

                    for (_, outputNode) in graph.getOutputNodes(for: currentNode.name) {
                        nodes.prepend(outputNode)
                    }
                } catch {
                    nodeRecords.append(RenderGraphNodeRecord(
                        label: currentNode.name.rawValue,
                        typeName: String(reflecting: Swift.type(of: currentNode.node)),
                        inputResources: inputs.map { RenderResourceSummary(slotValue: $0) },
                        outputResources: [],
                        pendingSubgraphs: [],
                        durationMilliseconds: Date().timeIntervalSince(nodeStartedAt) * 1000,
                        error: error.localizedDescription
                    ))
                    appendDiagnosticsRecord(
                        diagnostics: diagnostics,
                        frameIndex: frameIndex,
                        graph: graph,
                        isSubgraph: isSubgraph,
                        viewEntity: viewEntity,
                        executionOrder: executionOrder,
                        nodeRecords: nodeRecords,
                        pendingSubgraphLabels: pendingSubgraphLabels,
                        startedAt: graphStartedAt,
                        error: error.localizedDescription
                    )
                    throw error
                }
            }

            appendDiagnosticsRecord(
                diagnostics: diagnostics,
                frameIndex: frameIndex,
                graph: graph,
                isSubgraph: isSubgraph,
                viewEntity: viewEntity,
                executionOrder: executionOrder,
                nodeRecords: nodeRecords,
                pendingSubgraphLabels: pendingSubgraphLabels,
                startedAt: graphStartedAt,
                error: nil
            )
        } catch {
            throw error
        }

        tracer.trace("End Render Graph Frame")
    }

    private func appendDiagnosticsRecord(
        diagnostics: RenderGraphDiagnostics?,
        frameIndex: Int?,
        graph: RenderGraph,
        isSubgraph: Bool,
        viewEntity: Entity?,
        executionOrder: [String],
        nodeRecords: [RenderGraphNodeRecord],
        pendingSubgraphLabels: [String],
        startedAt: Date,
        error: String?
    ) {
        guard let diagnostics, let frameIndex else { return }
        diagnostics.append(RenderGraphFrameRecord(
            frameIndex: frameIndex,
            graphLabel: graph.label?.rawValue ?? "RenderGraph",
            isSubgraph: isSubgraph,
            viewEntityID: viewEntity?.id,
            viewEntityName: viewEntity?.name,
            executionOrder: executionOrder,
            nodes: nodeRecords,
            pendingSubgraphs: pendingSubgraphLabels,
            durationMilliseconds: Date().timeIntervalSince(startedAt) * 1000,
            error: error
        ))
    }
}
