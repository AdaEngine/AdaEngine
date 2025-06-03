//
//  RenderGraphContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

import AdaECS
import Logging

/// The context with all graph information required to run a ``RenderNode``.
/// This context is created for each node by the ``RenderGraphExecutor``.
@RenderGraphActor
public final class RenderGraphContext {
    public let graph: RenderGraph
    public let device: RenderDevice
    public let world: World
    public internal(set) var inputResources: [RenderSlotValue]
    public let tracer: Logger
    public let viewEntity: Entity?

    init(graph: RenderGraph, world: World, device: RenderDevice, inputResources: [RenderSlotValue], tracer: Logger, viewEntity: Entity?) {
        self.graph = graph
        self.device = device
        self.world = world
        self.tracer = tracer
        self.inputResources = inputResources
        self.viewEntity = viewEntity
    }
    
    internal var pendingSubgraphs: [(renderGraph: RenderGraph, inputs: [RenderSlotValue], viewEntity: Entity?)] = []
}

public extension RenderGraphContext {
    
    // FIXME: Should throws error!
    func runSubgraph(by name: String, inputs: [RenderSlotValue], viewEntity: Entity? = nil) {
        guard let graph = self.graph.subGraphs[name] else {
            return
        }

        if let inputResources = graph.entryNode?.node.inputResources {
            for (index, inputResource) in inputResources.enumerated() {
                if inputs[index].value.resourceKind != inputResource.kind {
                    return
                }
            }
        }
        
        self.pendingSubgraphs.append((graph, inputs, viewEntity))
    }

    func entityResource(by name: String) -> Entity? {
        self.inputResources.first(where: { $0.name == name })?.value.entity
    }

    func textureResource(by name: String) -> Texture? {
        self.inputResources.first(where: { $0.name == name })?.value.texture
    }

    func bufferResource(by name: String) -> Buffer? {
        self.inputResources.first(where: { $0.name == name })?.value.buffer
    }

    func samplerResource(by name: String) -> Sampler? {
        self.inputResources.first(where: { $0.name == name })?.value.sampler
    }
}

/// A global actor that is used to run render graph nodes.
@globalActor
public actor RenderGraphActor: GlobalActor {
    public static var shared = RenderGraphActor()
}
