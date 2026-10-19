//
//  UpscaleNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.11.2025.
//

import AdaECS
@_spi(Internal) import AdaRender
import Math

/// This node is responsible for presenting the result to the screen.
public struct UpscaleNode: RenderNode {
    public enum InputNode {
        public static let view: RenderSlot.Label = "view"
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
            let target = context.world.get(RenderViewTarget.self, from: viewEntity.id),
            let camera = context.world.get(Camera.self, from: viewEntity.id)
        else {
            return []
        }

        if let settings = target.pixelPerfect, let mainTexture = target.mainTexture, let outputTexture = target.outputTexture {
            presentPixelPerfect(
                settings: settings,
                main: mainTexture,
                output: outputTexture,
                view: viewEntity.id,
                world: context.world,
                renderContext: renderContext
            )
            return []
        }

        if let mainTexture = target.mainTexture,
            let outputTexture = target.outputTexture,
            mainTexture !== outputTexture {
            let commandBuffer = renderContext.commandQueue.makeCommandBuffer()
            commandBuffer.label = "Upscale Pass"

            if commandBuffer.encodeSpatialUpscale(source: mainTexture, destination: outputTexture) {
                commandBuffer.addCompletedHandler { [outputTexture] in
                    outputTexture.notifyRenderCompleted()
                }
                commandBuffer.commit()
                return []
            }

            guard let upscalePipeline = context.world.getResource(UpscalePipeline.self) else {
                return []
            }

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

            let resourceSet = RenderResourceSet(
                bindings: [
                    RenderResourceSet.Binding(
                        binding: 0,
                        shaderStages: .fragment,
                        resource: .texture(mainTexture)
                    ),
                    RenderResourceSet.Binding(
                        binding: 1,
                        shaderStages: .fragment,
                        resource: .sampler(upscalePipeline.sampler)
                    ),
                ]
            )
            renderPass.setResourceSet(resourceSet, index: 0)
            renderPass.setRenderPipelineState(upscalePipeline.renderPipeline)
            renderPass.draw(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            renderPass.endRenderPass()
            commandBuffer.addCompletedHandler { [outputTexture] in
                outputTexture.notifyRenderCompleted()
            }
            commandBuffer.commit()
        }

        return []
    }

    /// Presents a pixel-perfect camera: the UI node has already composed a full-resolution picture, or this node
    /// scales the low-resolution scene itself.
    private func presentPixelPerfect(
        settings: PixelPerfectSettings,
        main: RenderTexture,
        output: RenderTexture,
        view: Entity.ID,
        world: World,
        renderContext: RenderContext
    ) {
        guard
            let pipelines = world.getResource(PixelPerfectPipelines.self),
            let pictures = world.getResource(PixelPerfectPictures.self),
            let source = world.get(ExtractedCameraSource.self, from: view)?.entityId
        else {
            return
        }
        pictures.advanceFrame()
        let commandBuffer = renderContext.commandQueue.makeCommandBuffer()
        commandBuffer.label = "Pixel Perfect Present"
        if let picture = pictures.takeComposed(source) {
            PixelPerfectPresenter.copy(
                source: picture,
                into: output,
                pipeline: pipelines.output,
                sampler: pipelines.sampler,
                commandBuffer: commandBuffer,
                label: "Pixel Perfect Copy"
            )
        } else if let layout = PixelPerfectLayout(settings: settings, outputSize: Size(width: Float(output.width), height: Float(output.height))) {
            PixelPerfectPresenter.present(
                source: main,
                into: output,
                layout: layout,
                letterboxColor: settings.letterboxColor,
                pipeline: pipelines.output,
                sampler: pipelines.sampler,
                commandBuffer: commandBuffer,
                label: "Pixel Perfect Present"
            )
        } else {
            return
        }
        commandBuffer.addCompletedHandler { [output] in
            output.notifyRenderCompleted()
        }
        commandBuffer.commit()
    }
}
