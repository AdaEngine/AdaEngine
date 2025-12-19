//
//  UIRenderNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 19.12.2025.
//

import AdaECS
import AdaRender
import AdaUtils

public struct UIRenderNode: RenderNode {
    /// Input slots of render node.
    public enum InputNode {
        public static let view: RenderSlot.Label = "view"
    }

    @Query<
        Entity,
        Camera,
        RenderViewTarget
    >
    private var query

    @Res<RenderItems<UITransparentRenderItem>>
    private var renderItems

    public init() {}

    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]

    public func update(from world: World) {
        query.update(from: world)
        _renderItems.update(from: world)
    }

    public func execute(
        context: inout Context,
        renderContext: AdaRender.RenderContext
    ) async throws -> [AdaRender.RenderSlotValue] {
        guard let view = context.viewEntity else {
            return []
        }

        try query.forEach { entity, camera, target in
            if entity != view {
                return
            }

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

            if !renderItems.items.isEmpty {
                try renderItems.render(with: renderPass, world: context.world, view: view)
            }

            renderPass.endRenderPass()
            commandBuffer.commit()
        }

        return []
    }
}
