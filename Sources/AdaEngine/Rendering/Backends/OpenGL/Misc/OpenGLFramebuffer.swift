//
//  OpenGLFramebuffer.swift
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
import Math

final class OpenGLFramebuffer: Framebuffer {
    var attachments: [FramebufferAttachment] = []
    var descriptor: FramebufferDescriptor

    private var framebuffer: GLuint = 0
    var size: Math.SizeInt = .zero

    init(descriptor: FramebufferDescriptor) {
        self.descriptor = descriptor
        self.size.width = self.descriptor.width
        self.size.width = self.descriptor.height

        self.invalidate()
    }

    deinit {
        glDeleteFramebuffers(1, &framebuffer)
    }

    func resize(to newSize: Math.SizeInt) {
        guard newSize.width >= 0 && newSize.height >= 0 else {
            return
        }

        if self.size.width == newSize.width && self.size.height == newSize.height {
            return
        }
    }

    func invalidate() {
        if framebuffer != 0 {
            glDeleteFramebuffers(1, &framebuffer)
        }

        glGenFramebuffers(1, &framebuffer)
        for (index, attachmentDesc) in self.descriptor.attachments.enumerated() {
            let framebufferAttachment: FramebufferAttachment

            let texture = attachmentDesc.texture ?? RenderTexture(
                size: size,
                scaleFactor: self.descriptor.scale,
                format: attachmentDesc.format
            )

            var usage: FramebufferAttachmentUsage = []

            if attachmentDesc.format.isDepthFormat {
                usage.insert(.depthStencilAttachment)
            } else {
                usage.insert(.colorAttachment)
            }

            let gpuTexture = (texture.gpuTexture as! OpenGLTexture)

            glFramebufferTexture2D(
                GLenum(GL_FRAMEBUFFER),
                GLenum(GL_COLOR_ATTACHMENT0),
                GLenum(GL_TEXTURE_2D),
                gpuTexture.texture,
                0
            )
        }

        if glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) != GL_FRAMEBUFFER_COMPLETE {
            fatalError("Something go wrong")
        }
    }

    func bind() {
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        glViewport(0, 0, GLsizei(self.size.width), GLsizei(self.size.height))
    }
}
