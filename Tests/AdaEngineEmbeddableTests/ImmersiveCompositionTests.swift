#if os(macOS)
@testable import AdaEngineEmbeddable
import Metal
import Testing

@Suite("Immersive compositor GPU pixels", .serialized)
struct ImmersiveCompositionTests {
    @Test("Mixed mode leaves opaque offscreen backgrounds transparent to passthrough")
    func background() async throws {
        let result = try await render(color: [32, 64, 128, 255], depth: 1, passthrough: true)
        #expect(result.color == SIMD4<Float>.zero)
        #expect(result.depth == 0)
    }

    @Test("Full mode retains its authored background")
    func fullBackground() async throws {
        let result = try await render(color: [255, 255, 255, 255], depth: 1, passthrough: false)
        #expect(result.color == SIMD4<Float>(repeating: 1))
        #expect(result.depth > 0 && result.depth < 0.001)
    }

    @Test("Foreground keeps perspective depth and premultiplies its color", arguments: [true, false])
    func foreground(passthrough: Bool) async throws {
        let result = try await render(color: [255, 255, 255, 128], depth: 0.25, passthrough: passthrough)
        let alpha = Float(128) / 255
        #expect((0..<4).allSatisfy { abs(result.color[$0] - alpha) < 0.0001 })
        #expect(abs(result.depth - 0.75) < 0.0001)
    }

    @Test("Invisible pixels do not occlude passthrough or system hands")
    func zeroAlpha() async throws {
        let result = try await render(color: [255, 255, 255, 0], depth: 0.25, passthrough: true)
        #expect(result.color == SIMD4<Float>.zero)
        #expect(result.depth == 0)
    }

    private func render(color: [UInt8], depth: Double, passthrough: Bool) async throws -> (color: SIMD4<Float>, depth: Float) {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let queue = try #require(device.makeCommandQueue())
        let library = try await device.makeLibrary(source: ImmersiveCompositionShader.source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "immersiveVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "immersiveFragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba32Float
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.inputPrimitiveTopology = .triangle
        let pipeline = try await device.makeRenderPipelineState(descriptor: descriptor)
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .always
        depthDescriptor.isDepthWriteEnabled = true
        let depthState = try #require(device.makeDepthStencilState(descriptor: depthDescriptor))
        func texture(_ format: MTLPixelFormat, storage: MTLStorageMode) throws -> any MTLTexture {
            let description = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: 1, height: 1, mipmapped: false)
            description.storageMode = storage
            description.usage = [.shaderRead, .renderTarget]
            return try #require(device.makeTexture(descriptor: description))
        }
        let source = try texture(.rgba8Unorm, storage: .shared)
        try color.withUnsafeBytes {
            let address = try #require($0.baseAddress)
            source.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: address, bytesPerRow: 4)
        }
        let sourceDepth = try texture(.depth32Float, storage: .private)
        let output = try texture(.rgba32Float, storage: .shared)
        let outputDepth = try texture(.depth32Float, storage: .private)
        let readback = try #require(device.makeBuffer(length: 256, options: .storageModeShared))
        let commands = try #require(queue.makeCommandBuffer())
        let clear = MTLRenderPassDescriptor()
        clear.depthAttachment.texture = sourceDepth
        clear.depthAttachment.loadAction = .clear
        clear.depthAttachment.storeAction = .store
        clear.depthAttachment.clearDepth = depth
        try #require(commands.makeRenderCommandEncoder(descriptor: clear)).endEncoding()
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = outputDepth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .store
        pass.depthAttachment.clearDepth = 0
        let encoder = try #require(commands.makeRenderCommandEncoder(descriptor: pass))
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depthState)
        var layer: UInt32 = 0
        var mixed: UInt32 = passthrough ? 1 : 0
        encoder.setVertexBytes(&layer, length: MemoryLayout<UInt32>.stride, index: 0)
        encoder.setFragmentBytes(&mixed, length: MemoryLayout<UInt32>.stride, index: 0)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentTexture(sourceDepth, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        let blit = try #require(commands.makeBlitCommandEncoder())
        blit.copy(from: outputDepth, sourceSlice: 0, sourceLevel: 0, sourceOrigin: .init(x: 0, y: 0, z: 0), sourceSize: .init(width: 1, height: 1, depth: 1),
            to: readback, destinationOffset: 0, destinationBytesPerRow: 256, destinationBytesPerImage: 256)
        blit.endEncoding()
        let succeeded = await withCheckedContinuation { continuation in
            commands.addCompletedHandler { continuation.resume(returning: $0.status == .completed) }
            commands.commit()
        }
        try #require(succeeded)
        var pixel = SIMD4<Float>.zero
        output.getBytes(&pixel, bytesPerRow: 16, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)
        return (pixel, readback.contents().load(as: Float.self))
    }
}
#endif
