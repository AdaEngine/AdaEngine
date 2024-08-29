//
//  UIRenderPlugin.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.06.2024.
//

import Math

public struct UIRenderPlugin: RenderWorldPlugin {

    public static let renderGraph = "ui_render_graph"

    /// Input slots of render graph.
    public enum InputNode {
        public static let view = "view"
    }
    
    public init() {}

    public func setup(in world: RenderWorld) {
        DrawPassStorage.setDrawPass(UIDrawPass())

        let ui2d = getUIGraph()
        if let core2d = world.renderGraph.getSubgraph(by: Scene2DPlugin.renderGraph) {
            core2d.addSubgraph(ui2d, name: Self.renderGraph)
            core2d.addNode(RunGraphNode(graphName: Self.renderGraph), by: UIRenderNode.name)
            core2d.addNodeEdge(from: Main2DRenderNode.self, to: UIRenderNode.self)
        }
    }

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

    static let quadPosition: [Vector4] = [
        [-0.5, -0.5,  0.0, 1.0],
        [ 0.5, -0.5,  0.0, 1.0],
        [ 0.5,  0.5,  0.0, 1.0],
        [-0.5,  0.5,  0.0, 1.0]
    ]

    public func execute(context: Context) async throws -> [RenderSlotValue] {
        guard let view = context.viewEntity else {
            return []
        }

        guard let camera = view.components[Camera.self] else {
            return []
        }

        let clearColor = camera.clearFlags.contains(.solid) ? camera.backgroundColor : .gray
        let uiEntities = context.world.performQuery(Self.query)

        let drawList: DrawList
        switch camera.renderTarget {
        case .window(let windowId):
            if windowId == .empty {
                return []
            }

            drawList = try context.device.beginDraw(for: windowId, clearColor: clearColor)
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
            let framebuffer = context.device.createFramebuffer(from: desc)
            drawList = context.device.beginDraw(to: framebuffer, clearColors: [])
        }

        if let viewport = camera.viewport {
            drawList.setViewport(viewport)
        }

        var items = RenderItems<TransparentUIRenderItem>(items: [])
        for entity in uiEntities {
            let (renderComponent, camera) = entity.components[UIRenderTextureComponent.self, Camera.self]

            var spriteVerticies: [SpriteVertexData] = []

            for index in 0 ..< Self.quadPosition.count {
                let data = SpriteVertexData(
                    position: Transform3D.identity * Self.quadPosition[index],
                    color: .clear,
                    textureCoordinate: renderComponent.renderTexture.textureCoordinates[index],
                    textureIndex: 0
                )
                spriteVerticies.append(data)
            }

            let vertexBuffer = context.device.createVertexBuffer(
                length: spriteVerticies.count * MemoryLayout<SpriteVertexData>.stride,
                binding: 0
            )
            vertexBuffer.setData(&spriteVerticies, byteCount: spriteVerticies.count * MemoryLayout<SpriteVertexData>.stride)

            let indeciesCount = 6
            let indicies = Int(indeciesCount * 4)

            var quadIndices = [UInt32].init(repeating: 0, count: indicies)

            var offset: UInt32 = 0
            for index in stride(from: 0, to: indicies, by: 6) {
                quadIndices[index + 0] = offset + 0
                quadIndices[index + 1] = offset + 1
                quadIndices[index + 2] = offset + 2

                quadIndices[index + 3] = offset + 2
                quadIndices[index + 4] = offset + 3
                quadIndices[index + 5] = offset + 0

                offset += 4
            }

            let indexBuffer = context.device.createIndexBuffer(
                format: .uInt32,
                bytes: &quadIndices,
                length: indicies
            )

            let renderData = UIRenderData(
                vertexBuffer: vertexBuffer,
                indexBuffer: indexBuffer,
                textures: .init(repeating: renderComponent.renderTexture, count: 16)
            )

            items.items.append(TransparentUIRenderItem(
                entity: EmptyEntity {
                    renderData
                    camera
                },
                batchEntity: EmptyEntity(),
                drawPassId: UIDrawPass.identifier,
                renderPipeline: SpriteRenderPipeline.default.renderPipeline,
                sortKey: 0
            ))
        }

        try items.render(drawList, world: context.world, view: view)
        context.device.endDrawList(drawList)
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

@Component
struct UIRenderData {
    var vertexBuffer: VertexBuffer
    var indexBuffer: IndexBuffer
    var textures: [Texture]
}

struct UIDrawPass: DrawPass {
    func render(in context: Context, item: TransparentUIRenderItem) throws {
        guard let uiData = item.entity.components[UIRenderData.self] else {
            return
        }

        guard let cameraViewUniform = context.view.components[GlobalViewUniformBufferSet.self] else {
            return
        }

        context.drawList.pushDebugName("UIDrawPass")

        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        uiData.textures.enumerated().forEach { (index, texture) in
            context.drawList.bindTexture(texture, at: index)
        }

        context.drawList.appendUniformBuffer(uniformBuffer)
        context.drawList.appendVertexBuffer(uiData.vertexBuffer)
        context.drawList.bindIndexBuffer(uiData.indexBuffer)
        context.drawList.bindRenderPipeline(item.renderPipeline)
        context.drawList.drawIndexed(
            indexCount: item.batchRange?.count ?? 6, // indicies count per quad
            indexBufferOffset: Int(item.batchRange?.lowerBound ?? 0) * 4, // start position must be multiple by 4
            instanceCount: 1
        )

        context.drawList.popDebugName()

    }
}
