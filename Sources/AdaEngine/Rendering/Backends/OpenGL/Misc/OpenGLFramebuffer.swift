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

final class OpenGLFramebuffer: Framebuffer, @unchecked Sendable {
    var attachments: [FramebufferAttachment] = []
    var descriptor: FramebufferDescriptor

    private var framebuffer: GLuint = 0
    var size: Math.SizeInt = .zero

    init(descriptor: FramebufferDescriptor) {
        self.descriptor = descriptor
        self.size.width = self.descriptor.width
        self.size.height = self.descriptor.height

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

        self.size = newSize
        self.invalidate()
    }

    func invalidate() {
        if framebuffer != 0 {
            glDeleteFramebuffers(1, &framebuffer)
            self.attachments.removeAll()
        }

        glGenFramebuffers(1, &framebuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)

        for (index, attachmentDesc) in self.descriptor.attachments.enumerated() {
            let texture = attachmentDesc.texture ?? RenderTexture(
                size: size,
                scaleFactor: self.descriptor.scale,
                format: attachmentDesc.format
            )

            var usage: FramebufferAttachmentUsage = []

            let gpuTexture = (texture.gpuTexture as! OpenGLTexture)
            gpuTexture.bind()

            if attachmentDesc.format.isDepthFormat {
                usage.insert(.depthStencilAttachment)
                glFramebufferTexture2D(
                    GLenum(GL_FRAMEBUFFER),
                    GLenum(GL_DEPTH_ATTACHMENT),
                    GLenum(GL_TEXTURE_2D),
                    gpuTexture.texture,
                    0
                )
            } else {
                usage.insert(.colorAttachment)
                glFramebufferTexture2D(
                    GLenum(GL_FRAMEBUFFER),
                    GLenum(GL_COLOR_ATTACHMENT0) + GLenum(index),
                    GLenum(GL_TEXTURE_2D),
                    gpuTexture.texture,
                    0
                )
            }

            self.attachments.append(
                FramebufferAttachment(
                    texture: texture,
                    usage: usage,
                    slice: 0
                )
            )
        }

        if attachments.isEmpty {
            glDrawBuffer(GLenum(GL_NONE))
        } else {
            glDrawBuffer(GLenum(GL_COLOR_ATTACHMENT0))
        }

        let status = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        if status != GL_FRAMEBUFFER_COMPLETE {
            var errorMessage = "Framebuffer is not complete. Status: "
            switch Int32(status) {
            case GL_FRAMEBUFFER_UNDEFINED:
                errorMessage += "GL_FRAMEBUFFER_UNDEFINED - target is the default framebuffer"
            case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
                errorMessage += "GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT - some attachment point has no image attached"
            case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
                errorMessage += "GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT - no images are attached to the framebuffer"
            case GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER:
                errorMessage += "GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER - draw buffer incomplete"
            case GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER:
                errorMessage += "GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER - read buffer incomplete"
            case GL_FRAMEBUFFER_UNSUPPORTED:
                errorMessage += "GL_FRAMEBUFFER_UNSUPPORTED - combination of internal formats is not supported"
            case GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE:
                errorMessage += "GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE - inconsistent multisample settings"
            case GL_FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS:
                errorMessage += "GL_FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS - layered attachment mismatch"
            default:
                errorMessage += "Unknown error code: \(status)"
            }
            fatalError(errorMessage)
        }

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0);
    }

    func bind() {
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        glViewport(0, 0, GLsizei(self.size.width), GLsizei(self.size.height))
    }

    func unbind() {
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
    }
}
