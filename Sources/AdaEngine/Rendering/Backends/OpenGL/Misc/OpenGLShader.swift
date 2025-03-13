//
//  OpenGLShader.swift
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

final class OpenGLShader: CompiledShader {

    enum GLError: Error {
        case shaderCompilationError
    }

    let shader: GLuint

    init(shader: Shader) throws {
        let spirvShader = try shader.spirvCompiler.compile()
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

        self.shader = glShader
    }

    deinit {
        glDeleteShader(self.shader)
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

final class OpenGLProgram: Sendable {
    let program: GLuint

    init() {
        self.program = glCreateProgram()
    }

    func attach(to shader: OpenGLShader) {
        glAttachShader(program, shader.shader)
    }

    func link() {
        glLinkProgram(program)
    }

    func use() {
        glUseProgram(program)
    }

    deinit {
        glDeleteProgram(program)
    }
}
