//
//  OpenGLBuffer.swift
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

class OpenGLBuffer: Buffer, @unchecked Sendable {
    var label: String?
    var length: Int = 0
    var buffer: GLuint = 0
    var target: GLenum = GLenum(GL_ARRAY_BUFFER)
    private let usage: ResourceOptions

    init(size: Int, usage: ResourceOptions) {
        self.length = size
        self.usage = usage
    }

    final func initialize(data: UnsafeRawPointer? = nil) {
        glGenBuffersARB(1, &self.buffer)
        glBindBuffer(target, self.buffer)
        glBufferData(target, self.length, data, self.usage.glUsage)
    }

    final func bind() {
        glBindBuffer(target, self.buffer)
    }

    deinit {
        glDeleteBuffers(1, &self.buffer)
    }

    final func setData(_ bytes: UnsafeMutableRawPointer, byteCount: Int, offset: Int) {
        glBindBuffer(target, self.buffer)
        glBufferSubData(target, GLintptr(offset), GLsizeiptr(byteCount), bytes)
    }

    final func contents() -> UnsafeMutableRawPointer {
        glBindBuffer(target, self.buffer)
        return glMapBuffer(target, GLenum(GL_READ_WRITE))
    }
}

final class OpenGLVertexBuffer: OpenGLBuffer, VertexBuffer, @unchecked Sendable {
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
    }
}

final class OpenGLIndexBuffer: OpenGLBuffer, IndexBuffer, @unchecked Sendable {
    var indexFormat: IndexBufferFormat

    init(size: Int, format: IndexBufferFormat, usage: ResourceOptions) {
        self.indexFormat = format
        super.init(size: size, usage: usage)
    }
}

extension ResourceOptions {
    var glUsage: GLenum {
        switch self {
        case .storagePrivate:
            return GLenum(GL_STATIC_DRAW)
        case .storageShared:
            return GLenum(GL_DYNAMIC_DRAW)
        default:
            return GLenum(GL_DRAW_BUFFER)
        }
    }
}
