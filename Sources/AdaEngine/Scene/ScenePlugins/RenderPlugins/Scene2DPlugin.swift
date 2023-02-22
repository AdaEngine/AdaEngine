//
//  Scene2DPlugin.swift
//  
//
//  Created by v.prusakov on 2/19/23.
//

public struct Scene2DPlugin: ScenePlugin {
    
    public static let renderGraph = "render_graph_2d"
    
    public init() {}
    
    public enum InputNode {
        public static let view = "view"
    }
    
    public func setup(in scene: Scene) {
        // Add Systems
        
        scene.addSystem(ClearTransparent2DRenderItemsSystem.self)
        
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
        
        scene.sceneRenderGraph.addSubgraph(graph, name: Self.renderGraph)
    }
}

public struct ClearTransparent2DRenderItemsSystem: System {
    
    public static var dependencies: [SystemDependency] = [.before(SpriteRenderSystem.self)]
    
    static let query = EntityQuery(where: .has(RenderItems<Transparent2DRenderItem>.self))
    
    public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
//        context.scene.performQuery(Self.query).forEach { entity in
//            entity.components[RenderItems<Transparent2DRenderItem>.self]?.items.removeAll()
//        }
    }
}

public struct Main2DRenderNode: RenderNode {
    
    public static let name: String = "main_pass_2d"
    
    public enum InputNode {
        public static let view = "view"
    }
    
    public init() {}
    
    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]
    
    public func execute(context: Context) throws -> [RenderSlotValue] {
        guard let entity = context.entityResource(by: InputNode.view) else {
            return []
        }
        
        var (camera, renderItems) = entity.components[Camera.self, RenderItems<Transparent2DRenderItem>.self]
        
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
        
        // FIXME: Should be removed from here when we add a scene system graph
        renderItems.items.removeAll(keepingCapacity: true)
        entity.components[RenderItems<Transparent2DRenderItem>.self] = renderItems
        
        return []
    }
}

public struct RenderItems<T: RenderItem>: Component {
    public var items: [T]
    
    public init(items: [T] = []) {
        self.items = items
    }
    
    public mutating func sort() {
        self.items.sort(by: { $0.sortKey < $1.sortKey })
    }
    
    public func sorted() -> Self {
        var value = self
        value.items.sort(by: { $0.sortKey < $1.sortKey })
        return value
    }
    
    public func render(_ drawList: DrawList, world: World, view: Entity) throws {
        for item in self.items {
            guard let drawPass = DrawPassStorage.getDrawPass(for: item) else {
                continue
            }
            
            let context = RenderContext(
                device: .shared,
                entity: item.entity,
                world: world,
                view: view,
                drawList: drawList
            )
            
            try drawPass.render(in: context, item: item)
        }
    }
    
    private func render(in context: RenderContext, item: T, drawPass: any DrawPass<T>) throws {
        try drawPass.render(in: context, item: item)
    }
}

public struct DrawPassId: Equatable, Hashable {
    let id: Int
}

public protocol RenderItem {
    
    associatedtype SortKey: Comparable
    
    var entity: Entity { get }
    var drawPassId: DrawPassId { get }
    var sortKey: SortKey { get }
}

public struct RenderContext {
    public let device: RenderEngine
    public let entity: Entity
    public let world: World
    public let view: Entity
    public let drawList: DrawList
}

public protocol DrawPass<Item> {
    
    associatedtype Item: RenderItem
    typealias Context = RenderContext
    
    func render(in context: Context, item: Item) throws
}

public extension DrawPass {
    /// Return identifier of draw pass based on DrawPass.Type
    @inline(__always) static var identifier: DrawPassId {
        DrawPassId(id: Int(bitPattern: ObjectIdentifier(self)))
    }
}

public struct Transparent2DRenderItem: RenderItem {
    public var entity: Entity
    public var batchEntity: Entity
    public var drawPassId: DrawPassId
    public var renderPipeline: RenderPipeline
    public var sortKey: Float
    public var batchRange: Range<Int32>?
}

public enum DrawPassStorage {
    
    private static var draws: [DrawPassId: any DrawPass] = [:]
    
    private static let lock: NSLock = NSLock()
    
    public static func getDrawPass<I: RenderItem>(for item: I) -> AnyDrawPass<I>? {
        lock.lock()
        defer { lock.unlock() }
        guard let drawPass = draws[item.drawPassId] else {
            return nil
        }
        
        return AnyDrawPass(drawPass)
    }
    
    public static func setDrawPass<T: DrawPass>(_ drawPass: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = T.identifier
        draws[key] = drawPass
    }
}

public struct SpritePlugin: ScenePlugin {
    
    public init() {}
    
    public func setup(in scene: Scene) {
        scene.addSystem(SpriteRenderSystem.self)
        scene.addSystem(BatchTransparent2DItemsSystem.self)
        
        let spriteDraw = SpriteDrawPass()
        DrawPassStorage.setDrawPass(spriteDraw)
    }
}

public struct AnyDrawPass<T: RenderItem>: DrawPass {
    
    private var render: (Context, Any) throws -> Void
    
    public init<Value: DrawPass>(_ base: Value) {
        self.render = { context, item in
            try base.render(in: context, item: item as! Value.Item)
        }
    }
    
    public func render(in context: Context, item: T) throws {
        try render(context, item)
    }
}
