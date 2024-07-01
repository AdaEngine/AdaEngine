//
//  UIRenderPlugin.swift
//
//
//  Created by Vladislav Prusakov on 09.06.2024.
//

public struct UIRenderPlugin: ScenePlugin {
    
    public static let renderGraph = "render_ui_2d"
    
    /// Input slots of render graph.
    public enum InputNode {
        public static let view = "view"
    }
    
    public init() {}
    
    @RenderGraphActor
    public func setup(in scene: Scene) async {
        // Add Render graph
        let graph = RenderGraph()

        let entryNode = graph.addEntryNode(inputs: [
            RenderSlot(name: InputNode.view, kind: .entity)
        ])

        graph.addNode(with: UI2DRenderNode.name, node: UI2DRenderNode())
        graph.addSlotEdge(
            fromNode: entryNode,
            outputSlot: InputNode.view,
            toNode: UI2DRenderNode.name,
            inputSlot: UI2DRenderNode.InputNode.view
        )

        Application.shared.renderWorld.renderGraph.addSubgraph(graph, name: Self.renderGraph)
    }
}

public struct UI2DRenderNode: RenderNode {
    
    /// Input slots of render node.
    public enum InputNode {
        public static let view = "view"
    }
    
    public static let name: String = "ui_pass_2d"
    
    public func execute(context: Context) async throws -> [RenderSlotValue] {
        guard let entity = await context.entityResource(by: InputNode.view) else {
            return []
        }
        
        let (camera, renderItems) = entity.components[Camera.self, RenderItems<TransparentUIRenderItem>.self]
        
        if case .window(let id) = camera.renderTarget, id == .empty {
            return []
        }
        
        let sortedRenderItems = renderItems.sorted()
        let clearColor = camera.clearFlags.contains(.solid) ? camera.backgroundColor : .gray
        
        let drawList: DrawList
        
        switch camera.renderTarget {
        case .window(let windowId):
            drawList = RenderEngine.shared.beginDraw(for: windowId, clearColor: clearColor)
        case .texture(let texture):
            let desc = FramebufferDescriptor(
                scale: texture.scaleFactor,
                width: texture.width,
                height: texture.height,
                attachments: [
                    FramebufferAttachmentDescriptor(
                        format: texture.pixelFormat,
                        texture: texture,
                        clearColor: clearColor,
                        loadAction: .clear,
                        storeAction: .store
                    )
                ]
            )
            let framebuffer = RenderEngine.shared.makeFramebuffer(from: desc)
            drawList = RenderEngine.shared.beginDraw(to: framebuffer, clearColors: [])
        }
        
        if let viewport = camera.viewport {
            drawList.setViewport(viewport)
        }
        
        try sortedRenderItems.render(drawList, world: context.world, view: entity)
        
        RenderEngine.shared.endDrawList(drawList)
        
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
