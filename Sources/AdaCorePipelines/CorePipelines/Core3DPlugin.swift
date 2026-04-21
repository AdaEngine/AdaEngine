//
//  Core3DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaApp
import AdaECS
import AdaUtils
import AdaRender
import AdaTransform
import Math
import AdaAssets

/// Plugin for RenderWorld added 3D render capatibilites.
public struct Core3DPlugin: Plugin {

    public init() {}
    
    /// Input slots of render graph.
    public enum InputNode {
        public static let view: RenderSlot.Label = "view"
    }

    public func setup(in app: AppWorlds) {
        GLTFLoaderResolver.shared.setLoader(NativeGLTFLoader())
        
        guard let app = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        var graph = RenderGraph(label: .main3D)
        let entryNode = graph.addEntryNode(inputs: [
            RenderSlot(name: InputNode.view, kind: .entity)
        ])

        // graph.addNode(EmptyNode(), by: .Main3D.beginPass)
        // graph.addNode(Main3DRenderNode())
        // graph.addNode(EmptyNode(), by: .Main3D.endPass)

        // graph.addSlotEdge(
        //     fromNode: entryNode,
        //     outputSlot: InputNode.view,
        //     toNode: Main3DRenderNode.name,
        //     inputSlot: Main3DRenderNode.InputNode.view
        // )

        // graph.addNodeEdge(from: RenderNodeLabel.Main3D.beginPass, to: Main3DRenderNode.name)
        // graph.addNodeEdge(from: Main3DRenderNode.name, to: RenderNodeLabel.Main3D.endPass)

        app
            .getRefResource(RenderGraph.self)
            .wrappedValue
            .addSubgraph(graph, name: .main3D)
    }
}

public extension RenderGraph.Label {
    /// Render graph name.
    static let main3D: RenderGraph.Label = "Scene 3D Render Graph"
}

public extension RenderNodeLabel {
    enum Main3D {
        public static let beginPass: RenderNodeLabel = "Main3D.BeginPass"
        public static let endPass: RenderNodeLabel = "Main3D.EndPass"
    }
}
