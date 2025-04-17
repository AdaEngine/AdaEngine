//
//  OpenGLTexture.swift
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

final class OpenGLTexture: GPUTexture {
    let descriptor: TextureDescriptor
    var texture: GLuint = 0
    let target: GLenum

    init(
        texture: GLuint, 
        target: GLenum,
        descriptor: TextureDescriptor
    ) {
        self.texture = texture
        self.target = target
        self.descriptor = descriptor
    }

    init(descriptor: TextureDescriptor) throws {
        self.descriptor = descriptor

        let glType = descriptor.textureType.glType
        self.target = glType
        let internalFormat = descriptor.pixelFormat.glType
        let format = descriptor.pixelFormat.glFormat
        let minFilter = descriptor.samplerDescription.minFilter.glType
        let magFilter = descriptor.samplerDescription.magFilter.glType

        glGenTextures(1, &texture)
        glActiveTexture(GLenum(GL_TEXTURE0));
        glBindTexture(glType, texture)

        glTexParameteri(glType, GLenum(GL_TEXTURE_MIN_FILTER), minFilter)
        glTexParameteri(glType, GLenum(GL_TEXTURE_MAG_FILTER), magFilter)
        glTexParameteri(glType, GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT);
        glTexParameteri(glType, GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT);
        glTexParameteri(glType, GLenum(GL_TEXTURE_WRAP_R), GL_REPEAT);

        let pointer: UnsafeMutableBufferPointer<UInt8>? = descriptor.image.flatMap { .allocate(capacity: $0.data.count) }
        _ = pointer.flatMap { descriptor.image?.data.copyBytes(to: $0) }

        switch descriptor.textureType {
        case .texture1D, .texture1DArray:
            glTexImage1D(
                glType,
                GLint(descriptor.mipmapLevel),
                internalFormat,
                GLsizei(descriptor.width),
                0,
                GLenum(format),
                GLenum(GL_UNSIGNED_BYTE),
                pointer?.baseAddress
            )
        case .texture2D, .texture2DArray:
            glTexImage2D(
                glType,
                GLint(descriptor.mipmapLevel),
                internalFormat,
                GLsizei(descriptor.width),
                GLsizei(descriptor.height),
                0,
                GLenum(format),
                GLenum(GL_UNSIGNED_BYTE),
                pointer?.baseAddress
            )
        case .texture2DMultisample, .texture2DMultisampleArray:
            glTexImage2DMultisample(
                glType,
                GLsizei(0),
                internalFormat,
                GLsizei(descriptor.width),
                GLsizei(descriptor.height),
                GLboolean(GL_TRUE)
            )
        default:
            fatalErrorMethodNotImplemented()
        }

        pointer?.deallocate()

        let error = glGetError()
        if error != GL_NO_ERROR {
            fatalError("Failed to create texture: OpenGL error \(error)")
        }
    }

    deinit {
        glDeleteTextures(1, &texture)
    }

    func bind() {
        glBindTexture(target, texture)
    }

    func unbind() {
        glBindTexture(target, 0)
    }

    func getImage() -> Image? {
        return nil
    }
}

extension Texture.TextureType {
    var glType: GLenum {
        switch self {
        case .texture1D:
            return GLenum(GL_TEXTURE_1D)
        case .texture1DArray:
            return GLenum(GL_TEXTURE_1D_ARRAY)
        case .texture2D:
            return GLenum(GL_TEXTURE_2D)
        case .texture2DArray:
            return GLenum(GL_TEXTURE_2D_ARRAY)
        case .texture2DMultisample:
            return GLenum(GL_TEXTURE_2D_MULTISAMPLE)
        case .texture2DMultisampleArray:
            return GLenum(GL_TEXTURE_2D_MULTISAMPLE_ARRAY)
        case .textureCube:
            return GLenum(GL_TEXTURE_CUBE_MAP)
        case .texture3D:
            return GLenum(GL_TEXTURE_3D)
        case .textureBuffer:
            return GLenum(GL_TEXTURE_BUFFER)
        }
    }
}

extension SamplerMinMagFilter {
    var glType: GLint {
        switch self {
        case .nearest:
            return GL_NEAREST
        case .linear:
            return GL_LINEAR
        }
    }
}

extension SamplerMipFilter {
    var glType: GLint {
        switch self {
        case .nearest:
            return GL_LINEAR_MIPMAP_NEAREST
        case .linear:
            return GL_LINEAR_MIPMAP_LINEAR
        case .notMipmapped:
            return 0
        }
    }
}

extension PixelFormat {
    var glType: GLint {
        switch self {
        case .none:
            GL_NONE
        case .bgra8:
            GL_BGRA
        case .bgra8_srgb:
            GL_SRGB_ALPHA
        case .rgba8:
            GL_RGBA8
        case .rgba_16f:
            GL_RGBA16F
        case .rgba_32f:
            GL_RGBA32F
        case .depth_32f_stencil8:
            fatalError()
        case .depth_32f:
            GL_DEPTH_COMPONENT32F
        case .depth24_stencil8:
            GL_DEPTH_COMPONENT24
        }
    }

    var glFormat: GLint {
        switch self {
        case .rgba8, .rgba_16f, .rgba_32f, .bgra8, .bgra8_srgb:
            GL_RGBA
        case .depth_32f, .depth24_stencil8, .depth_32f_stencil8:
            GL_DEPTH_COMPONENT
        case .none:
            GL_NONE
        }
    }
}
