//
//  OpenGLRenderDevice.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 13.03.2025.
//

#if WASM
import WebGL
#endif
#if DARWIN
import OpenGL.GL3
#else
import OpenGL
#endif

final class OpenGLRenderDevice: RenderDevice {

    unowned let context: OpenGLBackend.Context?

    init(context: OpenGLBackend.Context? = nil) {
        self.context = context
    }

    func createUniformBuffer(length: Int, binding: Int) -> any UniformBuffer {
        let buffer = OpenGLUniformBuffer(size: length, binding: binding, usage: .storageShared)
        buffer.initialize()
        return buffer
    }

    func createBuffer(length: Int, options: ResourceOptions) -> any Buffer {
        let buffer = OpenGLBuffer(size: length, usage: options)
        buffer.initialize()
        return buffer
    }

    func createBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> any Buffer {
        let buffer = OpenGLBuffer(size: length, usage: options)
        buffer.initialize(data: bytes)
        return buffer
    }

    func createIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> any IndexBuffer {
        let buffer = OpenGLIndexBuffer(size: length, format: format, usage: .storagePrivate)
        buffer.initialize(data: bytes)
        return buffer
    }

    func createVertexBuffer(length: Int, binding: Int) -> any VertexBuffer {
        let buffer = OpenGLVertexBuffer(size: length, binding: binding, usage: .storagePrivate)
        buffer.initialize()
        return buffer
    }

    func compileShader(from shader: Shader) throws -> any CompiledShader {
        OpenGLBackend.currentContext?.makeCurrent()
        return try OpenGLShader(shader: shader)
    }

    func createFramebuffer(from descriptor: FramebufferDescriptor) -> any Framebuffer {
        OpenGLFramebuffer(descriptor: descriptor)
    }

    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> any RenderPipeline {
        OpenGLRenderPipeline(descriptor: descriptor)
    }

    func createSampler(from descriptor: SamplerDescriptor) -> any Sampler {
        OpenGLSampler(descriptor: descriptor)
    }

    func createUniformBufferSet() -> any UniformBufferSet {
        GenericUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }

    func createTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        do {
            OpenGLBackend.currentContext?.makeCurrent()
            return try OpenGLTexture(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func getImage(from texture: Texture) -> Image? {
        (texture.gpuTexture as? OpenGLTexture)?.getImage()
    }

    func beginDraw(
        for window: UIWindow.ID,
        clearColor: Color,
        loadAction: AttachmentLoadAction,
        storeAction: AttachmentStoreAction
    ) throws -> DrawList {
        guard let context else {
            throw DrawListError.notAGlobalDevice
        }
        guard let window = context.windows[window] else {
            throw DrawListError.windowNotExists
        }

        window.openGLContext.makeCurrent()
        return DrawList(
            commandBuffer: OpenGLDrawCommandBuffer(
                framebuffer: OpenGLFramebuffer(descriptor: FramebufferDescriptor())
            ),
            renderDevice: self
        )
    }

    func beginDraw(
        to framebuffer: any Framebuffer,
        clearColors: [Color]?
    ) throws -> DrawList {
        guard let framebuffer = framebuffer as? OpenGLFramebuffer else {
            throw DrawListError.failedToGetRenderPass
        }

        return DrawList(
            commandBuffer: OpenGLDrawCommandBuffer(framebuffer: framebuffer),
            renderDevice: self
        )
    }

    func draw(_ list: DrawList, indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        OpenGLBackend.currentContext?.makeCurrent()
        guard let renderPipeline = list.renderPipeline as? OpenGLRenderPipeline else {
            return
        }

        renderPipeline.program.use()

        list.vertexBuffers.forEach { buffer in
            (buffer as? OpenGLBuffer)?.bind()
        }

        (list.indexBuffer as? OpenGLBuffer)?.bind()

        list.textures.forEach { texture in
            (texture?.gpuTexture as? OpenGLTexture)?.bind()
            (texture?.sampler as? OpenGLSampler)?.bind()
        }

//        if let depthStencilState = renderPipeline.depthStencilState {
//            depthStencilState
//        }

        if let lineWidth = list.lineWidth {
            glLineWidth(lineWidth)
        }

        if list.isScissorEnabled {
            glScissor(
                GLint(list.scissorRect.origin.x),
                GLint(list.scissorRect.origin.y),
                GLsizei(list.scissorRect.size.width),
                GLsizei(list.scissorRect.size.height)
            )
        }

        if list.isViewportEnabled {
            glViewport(
                GLint(list.viewport.rect.origin.x),
                GLint(list.viewport.rect.origin.y),
                GLsizei(list.viewport.rect.size.width),
                GLsizei(list.viewport.rect.size.height)
            )
        }

        glCullFace(GLenum(renderPipeline.descriptor.backfaceCulling ? GL_BACK : GL_FRONT))
        glFrontFace(GLenum(GL_CCW))

        switch list.triangleFillMode {
        case .fill:
            glDrawElements(GLenum(GL_TRIANGLES), GLsizei(indexCount), GLenum(GL_UNSIGNED_INT), nil)
        case .lines:
            glDrawArrays(GLenum(GL_LINES), 0, GLsizei(indexCount))
        }
    }

    func endDrawList(_ drawList: DrawList) {
        OpenGLBackend.currentContext?.makeCurrent()
        glFlush()
    }
}

final class OpenGLDrawCommandBuffer: DrawCommandBuffer, Sendable {
    let framebuffer: OpenGLFramebuffer

    init(framebuffer: OpenGLFramebuffer) {
        self.framebuffer = framebuffer
    }
}

extension TriangleFillMode {
    var glType: GLenum {
        switch self {
        case .fill:
            GLenum(GL_TRIANGLES)
        case .lines:
            GLenum(GL_LINES)
        }
    }
}
