//
//  Scene2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

import AdaApp
import AdaECS

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
            // Add Render graph
            var graph = RenderGraph(label: "Scene2D")

            let entryNode = graph.addEntryNode(inputs: [
                RenderSlot(name: InputNode.view, kind: .entity)
            ])

            graph.addNode(Main2DRenderNode())
            graph.addSlotEdge(
                fromNode: entryNode,
                outputSlot: InputNode.view,
                toNode: Main2DRenderNode.name,
                inputSlot: Main2DRenderNode.InputNode.view
            )

            await app
                .main
                .getMutableResource(RenderGraph.self)
                .wrappedValue?
                .addSubgraph(graph, name: Self.renderGraph)
        }
    }
}

/// This render node responsible for rendering ``Transparent2DRenderItem``.
public struct Main2DRenderNode: RenderNode {
    
    /// Input slots of render node.
    public enum InputNode {
        public static let view = "view"
    }
    
    public init() {}
    
    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]
    
    public func execute(context: inout Context) async throws -> [RenderSlotValue] {
        guard let entity = context.entityResource(by: InputNode.view) else {
            return []
        }
        
        let (camera, renderItems) = entity.components[Camera.self, RenderItems<Transparent2DRenderItem>.self]
        if
            case .window(let windowRef) = camera.renderTarget,
            case .windowId(let id) = windowRef,
            id == .empty
        {
            return []
        }
        
        let sortedRenderItems = renderItems.sorted()
        let clearColor = camera.clearFlags.contains(.solid) ? camera.backgroundColor : .surfaceClearColor

        let drawList: DrawList
        switch camera.renderTarget {
        case .window(let windowId):
            drawList = try context.device.beginDraw(
                for: windowId,
                clearColor: clearColor,
                loadAction: .clear,
                storeAction: .store
            )
        case .texture(let textureHandle):
            let texture = textureHandle.asset
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
            let framebuffer = context.device.createFramebuffer(from: desc)
            drawList = try context.device.beginDraw(to: framebuffer, clearColors: [])
        }
        
        if let viewport = camera.viewport {
            drawList.setViewport(viewport)
        }
        
        try sortedRenderItems.render(drawList, world: context.world, view: entity)
        context.device.endDrawList(drawList)
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
    public var drawPass: any DrawPass
    
    /// Render Pipeline for rendering this item.
    public var renderPipeline: RenderPipeline
    
    /// Sort key used for rendering order.
    public var sortKey: Float
    
    /// If item support batch rendering, pass range of indecies.
    public var batchRange: Range<Int32>?

    public init(
        entity: Entity,
        batchEntity: Entity,
        drawPass: any DrawPass,
        renderPipeline: RenderPipeline,
        sortKey: Float,
        batchRange: Range<Int32>? = nil
    ) {
        self.entity = entity
        self.batchEntity = batchEntity
        self.drawPass = drawPass
        self.renderPipeline = renderPipeline
        self.sortKey = sortKey
        self.batchRange = batchRange
    }
}
