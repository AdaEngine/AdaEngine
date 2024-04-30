//
//  RenderGraphContext.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

/// The context with all graph information required to run a ``RenderNode``.
/// This context is created for each node by the ``RenderGraphExecutor``.
@RenderGraphActor
public final class RenderGraphContext {
    public let graph: RenderGraph
    public let device: RenderEngine
    public let world: World
    public internal(set) var inputResources: [RenderSlotValue]
    
    init(graph: RenderGraph, world: World, device: RenderEngine, inputResources: [RenderSlotValue]) {
        self.graph = graph
        self.device = device
        self.world = world
        self.inputResources = inputResources
    }
    
    internal var pendingSubgraphs: [(RenderGraph, [RenderSlotValue])] = []
}

public extension RenderGraphContext {
    
    @RenderGraphActor
    func runSubgraph(by name: String, inputs: [RenderSlotValue]) async {
        guard let graph = self.graph.subGraphs[name], let inputResources = graph.entryNode?.node.inputResources else {
            return
        }
        
        for (index, inputResource) in inputResources.enumerated() {
            if inputs[index].value.resourceKind != inputResource.kind {
                return
            }
        }
        
        self.pendingSubgraphs.append((graph, inputs))
    }
    
    @RenderGraphActor
    func entityResource(by name: String) async -> Entity? {
        self.inputResources.first(where: { $0.name == name })?.value.entity
    }
    
    @RenderGraphActor
    func textureResource(by name: String) async-> Texture? {
        self.inputResources.first(where: { $0.name == name })?.value.texture
    }
    
    @RenderGraphActor
    func bufferResource(by name: String) async -> Buffer? {
        self.inputResources.first(where: { $0.name == name })?.value.buffer
    }
    
    @RenderGraphActor
    func samplerResource(by name: String) async -> Sampler? {
        self.inputResources.first(where: { $0.name == name })?.value.sampler
    }
}

@globalActor
public actor RenderGraphActor: GlobalActor {
    public static var shared = RenderGraphActor()
}
