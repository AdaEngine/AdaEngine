//
//  OpenGLUniformBuffer.swift
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

final class OpenGLUniformBuffer: OpenGLBuffer, UniformBuffer, @unchecked Sendable {
    var binding: Int {
        get {
            return Int(self.buffer)
        }
        set {
            self.buffer = GLuint(newValue)
        }
    }

    init(size: Int, binding: Int, usage: ResourceOptions) {
        super.init(size: size, usage: usage)
        self.buffer = GLuint(binding)
        self.target = GLenum(GL_UNIFORM_BUFFER)
    }
}

