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
        public static let view: RenderSlot.Label = "view"
    }

    public func setup(in app: AppWorlds) {
        guard let app = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        // Add Systems
        app.insertResource(SortedRenderItems<Transparent2DRenderItem>())
        app.addSystem(BatchAndSortTransparent2DRenderItemsSystem.self, on: .prepare)

        var graph = RenderGraph(label: "Scene 2D Render Graph")
        let entryNode = graph.addEntryNode(inputs: [
            RenderSlot(name: InputNode.view, kind: .entity)
        ])

        graph.addNode(EmptyNode(), by: .Main2D.beginPass)
        graph.addNode(Main2DRenderNode())
        graph.addNode(EmptyNode(), by: .Main2D.endPass)
        graph.addNode(UpscaleNode())

        graph.addSlotEdge(
            fromNode: entryNode,
            outputSlot: InputNode.view,
            toNode: Main2DRenderNode.name,
            inputSlot: Main2DRenderNode.InputNode.view
        )

        graph.addNodeEdge(from: RenderNodeLabel.Main2D.beginPass, to: Main2DRenderNode.name)
        graph.addNodeEdge(from: Main2DRenderNode.name, to: RenderNodeLabel.Main2D.endPass)
        graph.addNodeEdge(from: RenderNodeLabel.Main2D.endPass, to: UpscaleNode.name)

        app
            .getRefResource(RenderGraph.self)
            .wrappedValue
            .addSubgraph(graph, name: Self.renderGraph)
    }
}

public extension RenderNodeLabel {
    enum Main2D {
        public static let beginPass: RenderNodeLabel = "Main2D.BeginPass"
        public static let endPass: RenderNodeLabel = "Main2D.EndPass"
    }
}
