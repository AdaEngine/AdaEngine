//
//  RenderGraphContext.swift
//  
//
//  Created by v.prusakov on 2/19/23.
//

public class RenderGraphContext {
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
    
    func runSubgraph(by name: String, inputs: [RenderSlotValue]) {
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
