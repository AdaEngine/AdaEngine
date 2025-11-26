//
//  Main2DRenderNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.11.2025.
//

import AdaECS
import AdaUtils

/// This render node responsible for rendering ``Transparent2DRenderItem``.
public struct Main2DRenderNode: RenderNode {

    /// Input slots of render node.
    public enum InputNode {
        public static let view = "view"
    }

    @Query<
        Entity,
        Camera,
        RenderItems<Transparent2DRenderItem>,
        RenderViewTarget
    >
    private var query

    public init() {}

    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]

    public func update(from world: World) {
        query.update(from: world)
    }

    public func execute(context: inout Context, renderContext: RenderContext) async throws -> [RenderSlotValue] {
        guard let view = context.viewEntity else {
            return []
        }

        try query.forEach { entity, camera, renderItems, target in
            if entity != view {
                return
            }

            let sortedRenderItems = renderItems.sorted()
            let clearColor = camera.clearFlags.contains(.solid) ? camera.backgroundColor : .surfaceClearColor
            let commandBuffer = renderContext.commandQueue.makeCommandBuffer()

            guard
                let texture = target.mainTexture
            else {
                return
            }

            let renderPass = commandBuffer.beginRenderPass(
                RenderPassDescriptor(
                    label: "Main 2d Render Pass",
                    colorAttachments: [
                        .init(
                            texture: texture,
                            operation: OperationDescriptor(
                                loadAction: .clear,
                                storeAction: .store
                            ),
                            clearColor: clearColor
                        )
                    ],
                    depthStencilAttachment: nil
                )
            )

            if let viewport = camera.viewport {
                renderPass.setViewport(viewport.rect)
            }

            if !sortedRenderItems.items.isEmpty {
                try sortedRenderItems.render(with: renderPass, world: context.world, view: view)
            }

            renderPass.endRenderPass()
            commandBuffer.commit()
        }

        return []
    }
}

/// An object describe 2D render item.
public struct Transparent2DRenderItem: RenderItem {

    /// An entity that hold additional information about render item.
    public var entity: Entity.ID

    /// An entity for batch rendering.
    public var batchEntity: Entity.ID

    /// Draw pass which will be used for rendering this item.
    public var drawPass: any DrawPass

    /// Render Pipeline for rendering this item.
    public var renderPipeline: RenderPipeline

    /// Sort key used for rendering order.
    public var sortKey: Float

    /// If item support batch rendering, pass range of indecies.
    public var batchRange: Range<Int32>?

    public init(
        entity: Entity.ID,
        batchEntity: Entity.ID,
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
