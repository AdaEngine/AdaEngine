//
//  HeadlessRenderBackend.swift
//  AdaEngine
//

import AdaUtils
import Math

final class HeadlessRenderBackend: RenderBackend, @unchecked Sendable {
    let renderDevice: RenderDevice = HeadlessRenderDevice()
    private var windows = SparseSet<WindowID, RenderWindow>()

    var type: RenderBackendType {
        .headless
    }

    func createLocalRenderDevice() -> RenderDevice {
        HeadlessRenderDevice()
    }

    @MainActor
    func createWindow(_ windowId: WindowID, for surface: RenderSurface, size: SizeInt) throws {
        windows.insert(
            RenderWindow(
                windowId: windowId,
                height: size.height,
                width: size.width,
                scaleFactor: surface.scaleFactor
            ),
            for: windowId
        )
    }

    @MainActor
    func resizeWindow(_ windowId: WindowID, newSize: SizeInt) throws {
        guard var window = windows.firstValue(for: windowId) else { return }
        window.width = newSize.width
        window.height = newSize.height
        windows.insert(window, for: windowId)
    }

    @MainActor
    func destroyWindow(_ windowId: WindowID) throws {
        windows.remove(for: windowId)
    }

    @MainActor
    func getRenderWindow(for windowId: WindowID) -> RenderWindow? {
        windows.firstValue(for: windowId)
    }

    @MainActor
    func getRenderWindows() throws -> RenderWindows {
        RenderWindows(windows: windows)
    }
}

private final class HeadlessRenderDevice: RenderDevice, @unchecked Sendable {
    func createBuffer(label: String?, length: Int, options: ResourceOptions) -> Buffer {
        HeadlessBuffer(label: label, length: length)
    }

    func createBuffer(label: String?, bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        let buffer = HeadlessBuffer(label: label, length: length)
        buffer.setData(UnsafeMutableRawPointer(mutating: bytes), byteCount: length, offset: 0)
        return buffer
    }

    func createIndexBuffer(label: String?, format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        let buffer = HeadlessIndexBuffer(label: label, length: length, indexFormat: format)
        buffer.setData(UnsafeMutableRawPointer(mutating: bytes), byteCount: length, offset: 0)
        return buffer
    }

    func createVertexBuffer(label: String?, length: Int, binding: Int) -> VertexBuffer {
        HeadlessVertexBuffer(label: label, length: length, binding: binding)
    }

    func compileShader(from shader: Shader) throws -> any CompiledShader {
        HeadlessCompiledShader()
    }

    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        HeadlessRenderPipeline(descriptor: descriptor)
    }

    func createSampler(from descriptor: SamplerDescriptor) -> Sampler {
        HeadlessSampler(descriptor: descriptor)
    }

    func createUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        HeadlessUniformBuffer(label: nil, length: length, binding: binding)
    }

    func createTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        HeadlessGPUTexture(descriptor: descriptor)
    }

    func getImage(from texture: Texture) -> Image? {
        nil
    }

    func createCommandQueue() -> CommandQueue {
        HeadlessCommandQueue()
    }

    @MainActor
    func createSwapchain(from window: WindowID) -> (any Swapchain)? {
        HeadlessSwapchain()
    }
}

private class HeadlessBuffer: Buffer, @unchecked Sendable {
    var label: String?
    let length: Int
    private let pointer: UnsafeMutableRawPointer

    init(label: String?, length: Int) {
        self.label = label
        self.length = length
        self.pointer = UnsafeMutableRawPointer.allocate(byteCount: max(length, 1), alignment: 1)
        self.pointer.initializeMemory(as: UInt8.self, repeating: 0, count: max(length, 1))
    }

    deinit {
        pointer.deallocate()
    }

    func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        guard byteCount > 0, offset < length else { return }
        pointer.advanced(by: offset).copyMemory(from: bytes, byteCount: min(byteCount, length - offset))
    }

    func contents() -> UnsafeMutableRawPointer {
        pointer
    }

    func unmap() {}
}

private final class HeadlessIndexBuffer: HeadlessBuffer, IndexBuffer {
    let indexFormat: IndexBufferFormat

    init(label: String?, length: Int, indexFormat: IndexBufferFormat) {
        self.indexFormat = indexFormat
        super.init(label: label, length: length)
    }
}

private final class HeadlessVertexBuffer: HeadlessBuffer, VertexBuffer {
    let binding: Int

    init(label: String?, length: Int, binding: Int) {
        self.binding = binding
        super.init(label: label, length: length)
    }
}

private final class HeadlessUniformBuffer: HeadlessBuffer, UniformBuffer {
    let binding: Int

    init(label: String?, length: Int, binding: Int) {
        self.binding = binding
        super.init(label: label, length: length)
    }
}

private final class HeadlessGPUTexture: GPUTexture, @unchecked Sendable {
    let size: SizeInt
    var label: String?

    init(descriptor: TextureDescriptor) {
        self.size = SizeInt(width: descriptor.width, height: descriptor.height)
        self.label = descriptor.debugLabel
    }

    func replaceRegion(_ region: RectInt, mipmapLevel: Int, withBytes bytes: UnsafeRawPointer, bytesPerRow: Int) {}
}

private final class HeadlessSampler: Sampler {
    let descriptor: SamplerDescriptor

    init(descriptor: SamplerDescriptor) {
        self.descriptor = descriptor
    }
}

private final class HeadlessCompiledShader: CompiledShader {}

private final class HeadlessRenderPipeline: RenderPipeline {
    let descriptor: RenderPipelineDescriptor

    init(descriptor: RenderPipelineDescriptor) {
        self.descriptor = descriptor
    }
}

private final class HeadlessCommandQueue: CommandQueue {
    func makeCommandBuffer() -> CommandBuffer {
        HeadlessCommandBuffer()
    }
}

private final class HeadlessCommandBuffer: CommandBuffer {
    var label: String?

    func beginRenderPass(_ desc: RenderPassDescriptor) -> RenderCommandEncoder {
        HeadlessRenderCommandEncoder()
    }

    func beginBlitPass(_ desc: BlitPassDescriptor) -> BlitCommandEncoder {
        HeadlessBlitCommandEncoder()
    }

    func commit() {}
}

private class HeadlessCommonCommandEncoder: CommonCommandEncoder {
    func pushDebugName(_ string: String) {}
    func popDebugName() {}
}

private final class HeadlessBlitCommandEncoder: HeadlessCommonCommandEncoder, BlitCommandEncoder {
    func copyTextureToTexture(
        source: Texture,
        sourceOrigin: Origin3D,
        sourceSize: Size3D,
        sourceMipLevel: Int,
        sourceSlice: Int,
        destination: Texture,
        destinationOrigin: Origin3D,
        destinationMipLevel: Int,
        destinationSlice: Int
    ) {}

    func copyBufferToBuffer(source: Buffer, sourceOffset: Int, destination: Buffer, destinationOffset: Int, size: Int) {}

    func copyBufferToTexture(
        source: Buffer,
        sourceOffset: Int,
        sourceBytesPerRow: Int,
        sourceBytesPerImage: Int,
        sourceSize: Size3D,
        destination: Texture,
        destinationOrigin: Origin3D,
        destinationMipLevel: Int,
        destinationSlice: Int
    ) {}

    func copyTextureToBuffer(
        source: Texture,
        sourceOrigin: Origin3D,
        sourceMipLevel: Int,
        sourceSlice: Int,
        sourceSize: Size3D,
        destination: Buffer,
        destinationOffset: Int,
        destinationBytesPerRow: Int,
        destinationBytesPerImage: Int
    ) {}

    func endBlitPass() {}
}

private final class HeadlessRenderCommandEncoder: HeadlessCommonCommandEncoder, RenderCommandEncoder {
    func setRenderPipelineState(_ pipeline: RenderPipeline) {}
    func setVertexBuffer(_ buffer: UniformBuffer, offset: Int, slot: Int) {}
    func setVertexBuffer(_ buffer: VertexBuffer, offset: Int, slot: Int) {}
    func setFragmentBuffer(_ buffer: UniformBuffer, offset: Int, slot: Int) {}
    func setVertexBuffer<T>(_ bufferData: BufferData<T>, offset: Int, slot: Int) {}
    func setFragmentBuffer<T>(_ bufferData: BufferData<T>, offset: Int, slot: Int) {}
    func setIndexBuffer<T>(_ bufferData: BufferData<T>, indexFormat: IndexBufferFormat) {}
    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, slot: Int) {}
    func setFragmentTexture(_ texture: Texture, slot: Int) {}
    func setFragmentSamplerState(_ sampler: Sampler, slot: Int) {}
    func setResourceSet(_ resourceSet: RenderResourceSet, index: Int) {}
    func setViewport(_ viewport: Rect) {}
    func setScissorRect(_ rect: Rect) {}
    func setTriangleFillMode(_ fillMode: TriangleFillMode) {}
    func setIndexBuffer(_ buffer: IndexBuffer, offset: Int) {}
    func drawIndexed(indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {}
    func draw(type: IndexPrimitive, vertexStart: Int, vertexCount: Int, instanceCount: Int) {}
    func endRenderPass() {}
}

private final class HeadlessSwapchain: Swapchain {
    let drawablePixelFormat: PixelFormat = .bgra8

    func getNextDrawable(_ renderDevice: RenderDevice) -> (any Drawable)? {
        nil
    }
}
