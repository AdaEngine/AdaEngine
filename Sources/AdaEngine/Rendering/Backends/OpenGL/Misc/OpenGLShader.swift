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
    let shader: GLuint
    let program: GLuint

    init(shader: GLuint, program: GLuint) {
        self.shader = shader
        self.program = program
    }

    deinit {
        glDeleteProgram(self.program)
        glDeleteShader(self.shader)
    }
}
