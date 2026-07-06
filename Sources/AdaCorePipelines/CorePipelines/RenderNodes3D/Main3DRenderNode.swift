//
//  Main3DRenderNode.swift
//  AdaEngine
//
//  Created by Codex on 07/06/26.
//

import AdaECS
@_spi(Internal) import AdaRender
import AdaUtils
import Math

/// This render node is responsible for rendering opaque 3D meshes.
public struct Main3DRenderNode: RenderNode {

    /// Input slots of render node.
    public enum InputNode {
        public static let view: RenderSlot.Label = "view"
    }

    @Query<
        Entity,
        Camera,
        RenderViewTarget,
        GlobalViewUniform
    >
    private var query

    @Res<RenderItems<Opaque3DRenderItem>>
    private var renderItems

    public init() {}

    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]

    public func update(from world: World) {
        query.update(from: world)
        _renderItems.update(from: world)
    }

    public func execute(context: inout Context, renderContext: RenderContext) async throws -> [RenderSlotValue] {
        guard let view = context.viewEntity else {
            return []
        }

        try query.forEach { entity, camera, target, uniform in
            if entity != view {
                return
            }

            guard let mainTexture = target.mainTexture else {
                return
            }

            let clearColor = camera.clearFlags.contains(.solid) ? camera.backgroundColor : .surfaceClearColor
            let commandBuffer = renderContext.commandQueue.makeCommandBuffer()
            commandBuffer.label = "Main 3d Render Pass"

            let depthAttachment = target.depthTexture.map {
                DepthStencilAttachmentDescriptor(
                    texture: $0,
                    depthOperation: OperationDescriptor(loadAction: .clear, storeAction: .store),
                    stencilOperation: OperationDescriptor(loadAction: .clear, storeAction: .store)
                )
            }

            let renderPass = commandBuffer.beginRenderPass(
                RenderPassDescriptor(
                    label: "Main 3d Render Pass",
                    colorAttachments: [
                        .init(
                            texture: mainTexture,
                            operation: OperationDescriptor(loadAction: .clear, storeAction: .store),
                            clearColor: clearColor
                        )
                    ],
                    depthStencilAttachment: depthAttachment
                )
            )

            renderPass.setVertexBuffer(uniform, slot: GlobalBufferIndex.viewUniform)
            renderPass.setViewport(camera.viewport.rect)

            if !renderItems.items.isEmpty {
                try renderItems.render(with: renderPass, world: context.world, view: view)
            }

            renderPass.endRenderPass()
            commandBuffer.commit()
        }

        return []
    }
}
