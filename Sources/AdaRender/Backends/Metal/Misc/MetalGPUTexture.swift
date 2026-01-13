//
//  MetalGPUTexture.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 13.03.2025.
//

#if METAL
import Math
import Metal

final class MetalGPUTexture: GPUTexture {
    var size: SizeInt {
        SizeInt(width: self.texture.width, height: self.texture.height)
    }

    public var label: String?

    var texture: MTLTexture

    init(texture: MTLTexture) {
        self.texture = texture
    }

    init(descriptor: TextureDescriptor, device: MTLDevice) {
        let textureDesc = MTLTextureDescriptor()

        switch descriptor.textureType {
        case .textureCube:
            textureDesc.textureType = .typeCube
        case .texture1D:
            textureDesc.textureType = .type1D
        case .texture1DArray:
            textureDesc.textureType = .type1DArray
        case .texture2D:
            textureDesc.textureType = .type2D
        case .texture2DArray:
            textureDesc.textureType = .type2DArray
        case .texture2DMultisample:
            textureDesc.textureType = .type2DMultisample
        case .texture2DMultisampleArray:
            textureDesc.textureType = .type2DMultisampleArray
        case .texture3D:
            textureDesc.textureType = .type3D
        case .textureBuffer:
            textureDesc.textureType = .typeTextureBuffer
        }

        var mtlUsage: MTLTextureUsage = []

        if descriptor.textureUsage.contains(.read) {
            mtlUsage.insert(.shaderRead)
        }

        if descriptor.textureUsage.contains(.write) {
            mtlUsage.insert(.shaderWrite)
        }

        if descriptor.textureUsage.contains(.renderTarget) {
            mtlUsage.insert(.renderTarget)
        }

        textureDesc.usage = mtlUsage
        textureDesc.width = descriptor.width
        textureDesc.height = descriptor.height
        textureDesc.pixelFormat = descriptor.pixelFormat.toMetal

        guard let texture = device.makeTexture(descriptor: textureDesc) else {
            fatalError("Cannot create texture")
        }

        texture.label = descriptor.debugLabel

        if let image = descriptor.image {
            let region = MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: image.width, height: image.height, depth: 1)
            )

            let bytesPerRow = descriptor.pixelFormat.bytesPerComponent * image.width

            unsafe image.data.withUnsafeBytes { buffer in
                unsafe precondition(buffer.baseAddress != nil, "Image should not contains empty address.")

                unsafe texture.replace(
                    region: region,
                    mipmapLevel: 0,
                    withBytes: buffer.baseAddress!,
                    bytesPerRow: bytesPerRow
                )
            }
        }

        self.texture = texture
    }

    // TODO: (Vlad) think about it later
    func getImage() -> Image? {
        if self.texture.isFramebufferOnly {
            return nil
        }

        let imageFormat: Image.Format
        let bytesInPixel: Int

        switch self.texture.pixelFormat {
        case .bgra8Unorm:
            imageFormat = .bgra8
            bytesInPixel = 4
        default:
            imageFormat = .rgba8
            bytesInPixel = 4
        }

        let bytesPerRow = self.texture.width * bytesInPixel
        let pixelCount = self.texture.width * self.texture.height

        var imageBytes = [UInt8](repeating: 0, count: pixelCount * bytesInPixel)
        unsafe self.texture.getBytes(
            &imageBytes,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: self.texture.width, height: self.texture.height, depth: 1)
            ),
            mipmapLevel: 0
        )

        return Image(
            width: self.texture.width,
            height: self.texture.height,
            data: Data(imageBytes),
            format: imageFormat
        )
    }
}

#endif
