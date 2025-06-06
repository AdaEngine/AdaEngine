//
//  OpenGLRenderDevice.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 13.03.2025.
//

#if OPENGL

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

        let framebufferDescriptor = FramebufferDescriptor(
            scale: 1,
            width: window.size.width,
            height: window.size.height,
            sampleCount: 1,
            attachments: [
               FramebufferAttachmentDescriptor(
                format: .bgra8,
                texture: nil,
                clearColor: clearColor,
                loadAction: loadAction,
                storeAction: storeAction
               ),
               FramebufferAttachmentDescriptor(
                format: .depth_32f,
                texture: nil,
                clearColor: Color(0, 0, 0, 1),
                loadAction: .load,
                storeAction: .store
               )
            ]
        )
        
        let framebuffer = OpenGLFramebuffer(descriptor: framebufferDescriptor)
        return DrawList(
            commandBuffer: OpenGLDrawCommandBuffer(
                framebuffer: framebuffer
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
        guard let drawCommandBuffer = list.commandBuffer as? OpenGLDrawCommandBuffer else {
            return
        }
        let framebuffer = drawCommandBuffer.framebuffer
        framebuffer.bind()

        try! checkOpenGLError()

        framebuffer.attachments.forEach { attachment in
            if attachment.usage.contains(.depthStencilAttachment) {
                glClear(GLenum(GL_DEPTH_BUFFER_BIT) | GLenum(GL_STENCIL_BUFFER_BIT))
                glClearDepth(framebuffer.descriptor.clearDepth)
            }

            glClear(GLenum(GL_COLOR_BUFFER_BIT))
            if attachment.usage.contains(.colorAttachment) {
                glClearColor(
                    attachment.clearColor.red,
                    attachment.clearColor.green,
                    attachment.clearColor.blue,
                    attachment.clearColor.alpha
                )
            }
        }

        try! checkOpenGLError()

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

        try! checkOpenGLError()

        glCullFace(GLenum(renderPipeline.descriptor.backfaceCulling ? GL_BACK : GL_FRONT))
        glFrontFace(GLenum(GL_CCW))

        try! checkOpenGLError()
        renderPipeline.program.use()

        try! checkOpenGLError()
        list.vertexBuffers.forEach { buffer in
            (buffer as? OpenGLBuffer)?.bind()
        }

        try! checkOpenGLError()

        (list.indexBuffer as? OpenGLBuffer)?.bind()

        try! checkOpenGLError()

        list.textures.forEach { texture in
            (texture?.gpuTexture as? OpenGLTexture)?.bind()
            (texture?.sampler as? OpenGLSampler)?.bind()
        }

        try! checkOpenGLError()

        switch list.triangleFillMode {
        case .fill:
            glDrawElements(GLenum(GL_TRIANGLES), GLsizei(indexCount), GLenum(GL_UNSIGNED_INT), nil)
        case .lines:
            glDrawArrays(GLenum(GL_LINES), 0, GLsizei(indexCount))
        }

        try! checkOpenGLError()
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

#endif
