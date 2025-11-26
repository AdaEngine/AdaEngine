//
//  UpscaleNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.11.2025.
//

import AdaECS
import Math

/// This node is responsible for presenting the result to the screen.
public struct UpscaleNode: RenderNode {

    public enum InputNode {
        public static let view = "view"
    }

    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]

    public init() {}

    public func execute(
        context: inout Context,
        renderContext: RenderContext
    ) async throws -> [RenderSlotValue] {
        guard
            let viewEntity = context.viewEntity,
            let target = viewEntity.components[RenderViewTarget.self],
            let camera = viewEntity.components[Camera.self]
        else {
            return []
        }

        guard let upsalePipeline = context.world.getResource(UpscalePipeline.self) else {
            return []
        }

        if let mainTexture = target.mainTexture,
           let outputTexture = target.outputTexture,
           mainTexture !== outputTexture {
            let commandBuffer = renderContext.commandQueue.makeCommandBuffer()
            let renderPass = commandBuffer.beginRenderPass(
                RenderPassDescriptor(
                    label: "Upscale Pass",
                    colorAttachments: [
                        .init(
                            texture: outputTexture,
                            operation: OperationDescriptor(
                                loadAction: .clear,
                                storeAction: .store
                            ),
                            clearColor: camera.backgroundColor
                        )
                    ],
                    depthStencilAttachment: nil
                )
            )

            // This code doesn't work
            if let viewport = camera.viewport, Int(viewport.rect.width) == outputTexture.width && Int(viewport.rect.height) == outputTexture.height {
                renderPass.setScissorRect(viewport.rect)
            }

            renderPass.setFragmentTexture(mainTexture, index: 0)
            renderPass.setFragmentSamplerState(upsalePipeline.sampler, index: 0)
            renderPass.setRenderPipelineState(upsalePipeline.renderPipeline)

            renderPass.draw(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            renderPass.endRenderPass()
            commandBuffer.commit()
        }

        return []
    }
}
