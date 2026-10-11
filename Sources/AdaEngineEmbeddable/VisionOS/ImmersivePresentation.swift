#if os(visionOS)
    @_spi(Internal) import AdaRender
    import CompositorServices
    import Metal

    /// Converts Ada's forward-depth offscreen result to the compositor's reverse-depth attachments.
    @available(visionOS 26.0, *)
    @MainActor
    final class ImmersivePresentation {
        let queue: any MTLCommandQueue
        private let pipeline: any MTLRenderPipelineState
        private let depthState: any MTLDepthStencilState
        private let preservesPassthrough: Bool

        init(queue: any MTLCommandQueue, colorFormat: MTLPixelFormat, depthFormat: MTLPixelFormat, preservesPassthrough: Bool) throws {
            self.queue = queue
            self.preservesPassthrough = preservesPassthrough
            let library = try queue.device.makeLibrary(source: ImmersiveCompositionShader.source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "immersiveVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "immersiveFragment")
            descriptor.colorAttachments[0].pixelFormat = colorFormat
            descriptor.depthAttachmentPixelFormat = depthFormat
            descriptor.inputPrimitiveTopology = .triangle
            pipeline = try queue.device.makeRenderPipelineState(descriptor: descriptor)
            let depth = MTLDepthStencilDescriptor()
            depth.depthCompareFunction = .always
            depth.isDepthWriteEnabled = true
            guard let depthState = queue.device.makeDepthStencilState(descriptor: depth) else {
                throw ImmersiveRendererError.metalResourceUnavailable
            }
            self.depthState = depthState
        }

        func present(_ drawable: LayerRenderer.Drawable, eyes: [(RenderTexture, RenderTexture)], overlays: ((any MTLCommandBuffer) -> Void)? = nil, onSubmitted: () -> Void) async throws {
            guard let commands = queue.makeCommandBuffer() else { throw ImmersiveRendererError.metalResourceUnavailable }
            for (index, view) in drawable.views.enumerated() {
                guard index < eyes.count,
                    let color = MetalInterop.texture(eyes[index].0),
                    let depth = MetalInterop.texture(eyes[index].1)
                else {
                    throw ImmersiveRendererError.missingEyeTarget
                }
                let map = view.textureMap
                let textureIndex = map.textureIndex
                let pass = MTLRenderPassDescriptor()
                let rateMaps = drawable.rasterizationRateMaps
                let rateMap = rateMaps.indices.contains(textureIndex) ? rateMaps[textureIndex] : nil
                pass.rasterizationRateMap = rateMap
                let layeredFoveation = (rateMap?.layerCount ?? 1) > 1
                pass.renderTargetArrayLength = layeredFoveation ? (rateMap?.layerCount ?? 1) : 1
                pass.colorAttachments[0].texture = drawable.colorTextures[textureIndex]
                pass.colorAttachments[0].slice = layeredFoveation ? 0 : map.sliceIndex
                let preserveOtherEye = layeredFoveation && drawable.views.prefix(index).contains { $0.textureMap.textureIndex == textureIndex }
                pass.colorAttachments[0].loadAction = preserveOtherEye ? .load : .clear
                pass.colorAttachments[0].storeAction = .store
                pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: preservesPassthrough ? 0 : 1)
                pass.depthAttachment.texture = drawable.depthTextures[textureIndex]
                pass.depthAttachment.slice = layeredFoveation ? 0 : map.sliceIndex
                pass.depthAttachment.clearDepth = 0
                pass.depthAttachment.loadAction = preserveOtherEye ? .load : .clear
                pass.depthAttachment.storeAction = .store
                guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
                    throw ImmersiveRendererError.metalResourceUnavailable
                }
                encoder.setViewport(map.viewport)
                var layerIndex = UInt32(layeredFoveation ? map.sliceIndex : 0)
                unsafe encoder.setVertexBytes(&layerIndex, length: MemoryLayout<UInt32>.stride, index: 0)
                encoder.setRenderPipelineState(pipeline)
                encoder.setDepthStencilState(depthState)
                encoder.setFragmentTexture(color, index: 0)
                encoder.setFragmentTexture(depth, index: 1)
                var passthrough: UInt32 = preservesPassthrough ? 1 : 0
                unsafe encoder.setFragmentBytes(&passthrough, length: MemoryLayout<UInt32>.stride, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
            }
            overlays?(commands)
            drawable.encodePresent(commandBuffer: commands)
            try await complete(commands, retaining: eyes, onSubmitted: onSubmitted)
        }

        /// A nonblocking fence before rendering the next eye with shared per-view uniform scratch.
        func finishEye() async throws {
            guard let commands = queue.makeCommandBuffer() else { throw ImmersiveRendererError.metalResourceUnavailable }
            try await complete(commands, retaining: [])
        }

        private func complete(_ commands: any MTLCommandBuffer, retaining eyes: [(RenderTexture, RenderTexture)], onSubmitted: () -> Void = {}) async throws {
            let succeeded = await withCheckedContinuation { continuation in
                commands.addCompletedHandler { buffer in
                    // Explicitly retain sampled textures until the GPU is finished.
                    _ = eyes
                    continuation.resume(returning: buffer.status == .completed)
                }
                commands.commit()
                onSubmitted()
            }
            guard succeeded else { throw ImmersiveRendererError.gpuSubmissionFailed }
        }

    }
#endif
