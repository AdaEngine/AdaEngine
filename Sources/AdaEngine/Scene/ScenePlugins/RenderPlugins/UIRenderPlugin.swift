//
//  UIRenderPlugin.swift
//
//
//  Created by Vladislav Prusakov on 09.06.2024.
//

public struct UIRenderPlugin: ScenePlugin {
    
    public static let renderGraph = "ui_render_graph"

    /// Input slots of render graph.
    public enum InputNode {
        public static let view = "view"
    }
    
    public init() {}
    
    @RenderGraphActor
    public func setup(in scene: Scene) async {
        let ui2d = getUIGraph()
        if let core2d = Application.shared.renderWorld.renderGraph.getSubgraph(by: Scene2DPlugin.renderGraph) {
            core2d.addSubgraph(ui2d, name: Self.renderGraph)
            core2d.addNode(RunGraphNode(graphName: Self.renderGraph), by: UIRenderNode.name)
            core2d.addNodeEdge(from: Main2DRenderNode.self, to: UIRenderNode.self)
        }
    }

    @RenderGraphActor
    private func getUIGraph() -> RenderGraph {
        let graph = RenderGraph(label: "UIRender")
        graph.addNode(UIRenderNode())
        return graph
    }
}

public struct UIRenderNode: RenderNode {
    
    /// Input slots of render node.
    public enum InputNode {
        public static let view = "view"
    }
    
    public static let name: String = "UIRenderNode"

    static let query = EntityQuery(where: .has(UIRenderTextureComponent.self))

    public func execute(context: Context) async throws -> [RenderSlotValue] {
        let uiEntities = context.world.performQuery(Self.query)
        for entity in uiEntities {
            
        }
        return []
    }
}

/// An object describe 2D render item.
public struct TransparentUIRenderItem: RenderItem {
    
    /// An entity that hold additional information about render item.
    public var entity: Entity
    
    /// An entity for batch rendering.
    public var batchEntity: Entity
    
    /// Draw pass which will be used for rendering this item.
    public var drawPassId: DrawPassId
    
    /// Render Pipeline for rendering this item.
    public var renderPipeline: RenderPipeline
    
    /// Sort key used for rendering order.
    public var sortKey: Float
    
    /// If item support batch rendering, pass range of indecies.
    public var batchRange: Range<Int32>?
}

@Component
struct UIRenderTextureComponent {
    var renderTexture: RenderTexture
}
