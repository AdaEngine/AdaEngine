//
//  Upscaling.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 26.11.2025.
//

import AdaApp
import AdaAssets
import AdaECS
import AdaUtils
import Math

struct UpscalePlugin: Plugin {
    func setup(in app: borrowing AdaApp.AppWorlds) {
        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }
        let renderDevice = renderWorld.getResource(RenderDeviceHandler.self)
            .unwrap(message: "Failed to fetch RenderDevice from world")
            .renderDevice

        renderWorld
            .insertResource(UpscalePipeline(device: renderDevice))
    }
}

public struct UpscalePipeline: Resource {

    public let renderPipeline: RenderPipeline
    public let sampler: Sampler

    public init(device: RenderDevice) {
        let spriteShader = try! AssetsManager.loadSync(
            ShaderModule.self,
            at: "Shaders/FullScreenShader.glsl",
            from: .module
        )

        var descriptor = RenderPipelineDescriptor()
        descriptor.debugName = "Upscale Pipeline"

        descriptor.vertex = spriteShader.asset.getShader(for: .vertex)
        descriptor.fragment = spriteShader.asset.getShader(for: .fragment)
        descriptor.colorAttachments = [
            RenderPipelineColorAttachmentDescriptor(format: .bgra8)
        ]

        self.renderPipeline = device.createRenderPipeline(from: descriptor)
        self.sampler = device.createSampler(from: SamplerDescriptor())
    }
}
