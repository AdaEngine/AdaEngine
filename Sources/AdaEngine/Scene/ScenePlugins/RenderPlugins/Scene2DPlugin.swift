//
//  Scene2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

/// Plugin for RenderWorld added 2D render capatibilites.
public struct Scene2DPlugin: ScenePlugin {
    
    /// Render graph name.
    public static let renderGraph = "render_graph_2d"
    
    public init() {}
    
    /// Input slots of render graph.
    public enum InputNode {
        public static let view = "view"
    }
    
    @RenderGraphActor
    public func setup(in scene: Scene) async {
        // Add Systems
        await scene.addSystem(BatchTransparent2DItemsSystem.self)

        // Add Render graph
        let graph = RenderGraph()

        let entryNode = graph.addEntryNode(inputs: [
            RenderSlot(name: InputNode.view, kind: .entity)
        ])

        graph.addNode(with: Main2DRenderNode.name, node: Main2DRenderNode())
        graph.addSlotEdge(
            fromNode: entryNode,
            outputSlot: InputNode.view,
            toNode: Main2DRenderNode.name,
            inputSlot: Main2DRenderNode.InputNode.view
        )

        Application.shared.renderWorld.renderGraph.addSubgraph(graph, name: Self.renderGraph)
    }
}

/// This render node responsible for rendering ``Transparent2DRenderItem``.
public struct Main2DRenderNode: RenderNode {
    
    public static let name: String = "main_pass_2d"
    
    /// Input slots of render node.
    public enum InputNode {
        public static let view = "view"
    }
    
    public init() {}
    
    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]
    
    public func execute(context: Context) async throws -> [RenderSlotValue] {
        guard let entity = await context.entityResource(by: InputNode.view) else {
            return []
        }
        
        let (camera, renderItems) = entity.components[Camera.self, RenderItems<Transparent2DRenderItem>.self]
        
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
public struct Transparent2DRenderItem: RenderItem {
    
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
