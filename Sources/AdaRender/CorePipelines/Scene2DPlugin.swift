//
//  Scene2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

import AdaApp
import AdaECS
import AdaUtils
import Math

/// Plugin for RenderWorld added 2D render capatibilites.
public struct Scene2DPlugin: Plugin {

    /// Render graph name.
    public static let renderGraph = "render_graph_2d"
    
    public init() {}
    
    /// Input slots of render graph.
    public enum InputNode {
        public static let view = "view"
    }

    public func setup(in app: AppWorlds) {
        guard let app = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        // Add Systems
        app.addSystem(BatchTransparent2DItemsSystem.self)

        Task { @RenderGraphActor in
            var graph = RenderGraph(label: "Scene 2D Render Graph")
            let entryNode = graph.addEntryNode(inputs: [
                RenderSlot(name: InputNode.view, kind: .entity)
            ])

            graph.addNode(Main2DRenderNode())
            graph.addNode(UpscaleNode())

            graph.addSlotEdge(
                fromNode: entryNode,
                outputSlot: InputNode.view,
                toNode: Main2DRenderNode.name,
                inputSlot: Main2DRenderNode.InputNode.view
            )
            graph.addNodeEdge(from: Main2DRenderNode.name, to: UpscaleNode.name)

            await app
                .getRefResource(RenderGraph.self)
                .wrappedValue
                .addSubgraph(graph, name: Self.renderGraph)
        }
    }
}
