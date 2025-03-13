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

    enum GLError: Error {
        case shaderCompilationError
    }

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
        let spirvShader = try shader.spirvCompiler.compile()
        let program = glCreateProgram()
        let glShader = glCreateShader(shader.stage.glType)

        spirvShader.source.withCString { pointer in
            var ptr: UnsafePointer<GLchar>? = UnsafePointer<GLchar>(pointer)
            return glShaderSource(glShader, 1, &ptr, nil)
        }

        glCompileShader(glShader)

        var result: GLint = 0
        glGetShaderiv(glShader, GLenum(GL_COMPILE_STATUS), &result)

        if result != 0 {
            throw GLError.shaderCompilationError
        }

        glAttachShader(program, glShader)
        glLinkProgram(program)

        return OpenGLShader(shader: glShader, program: program)
    }

    func createFramebuffer(from descriptor: FramebufferDescriptor) -> any Framebuffer {
        fatalErrorMethodNotImplemented()
    }

    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> any RenderPipeline {
        fatalErrorMethodNotImplemented()
    }

    func createSampler(from descriptor: SamplerDescriptor) -> any Sampler {
        fatalErrorMethodNotImplemented()
    }

    func createUniformBufferSet() -> any UniformBufferSet {
        GenericUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }

    func createTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        fatalErrorMethodNotImplemented()
    }

    func getImage(from texture: Texture) -> Image? {
        fatalErrorMethodNotImplemented()
    }

    func beginDraw(for window: UIWindow.ID, clearColor: Color, loadAction: AttachmentLoadAction, storeAction: AttachmentStoreAction) throws -> DrawList {
        fatalErrorMethodNotImplemented()
    }

    func beginDraw(to framebuffer: any Framebuffer, clearColors: [Color]?) throws -> DrawList {
        fatalErrorMethodNotImplemented()
    }

    func draw(_ list: DrawList, indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        fatalErrorMethodNotImplemented()
    }

    func endDrawList(_ drawList: DrawList) {
        fatalErrorMethodNotImplemented()
    }
}

private extension ShaderStage {
    var glType: GLenum {
        switch self {
        case .vertex:
            return GLenum(GL_VERTEX_SHADER)
        case .fragment:
            return GLenum(GL_FRAGMENT_SHADER)
        case .compute:
            #if DARWIN
            fatalErrorMethodNotImplemented()
            #else
            return GLenum(GL_COMPUTE_SHADER)
            #endif
        case .tesselationControl:
            return GLenum(GL_TESS_CONTROL_SHADER)
        case .tesselationEvaluation:
            return GLenum(GL_TESS_EVALUATION_SHADER)
        case .max:
            return .max
        }
    }
}
