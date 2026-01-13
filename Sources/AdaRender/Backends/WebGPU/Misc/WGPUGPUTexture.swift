//
//  WGPUGPUTexture.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 13.03.2025.
//

#if canImport(WebGPU)
import Math
import WebGPU
import Foundation

public final class WGPUGPUTexture: GPUTexture {

    public var size: SizeInt {
        SizeInt(width: Int(self.texture.width), height: Int(self.texture.height))
    }

    public var label: String?

    public let texture: WebGPU.Texture
    public let textureView: WebGPU.TextureView

    deinit {
        print("WGPUGPUTexture deinit", self.label)
    }

    init(texture: WebGPU.Texture, textureView: WebGPU.TextureView) {
        self.texture = texture
        self.textureView = textureView
    }

    init(descriptor: TextureDescriptor, device: WebGPU.Device) {
        var wgpuUsage: WebGPU.TextureUsage = []

        if descriptor.textureUsage.contains(.read) {
            wgpuUsage.insert(.copyDst)
            wgpuUsage.insert(.textureBinding)
        }

        if descriptor.textureUsage.contains(.write) {
            wgpuUsage.insert(.copySrc)
        }

        if descriptor.textureUsage.contains(.renderTarget) {
            wgpuUsage.insert(.renderAttachment)
        }
        
        // Always add textureBinding for textures that will be sampled in shaders
        if !descriptor.textureUsage.contains(.renderTarget) {
            wgpuUsage.insert(.textureBinding)
        }

        let textureDesc = WebGPU.TextureDescriptor(
            label: descriptor.debugLabel,
            usage: wgpuUsage,
            dimension: descriptor.textureType.toWebGPUTextureDimension,
            size: Extent3d(
                width: UInt32(descriptor.width),
                height: UInt32(descriptor.height),
                depthOrArrayLayers: 1
            ),
            format: descriptor.pixelFormat.toWebGPU,
            mipLevelCount: 1,
            sampleCount: 1,
            viewFormats: [
                descriptor.pixelFormat.toWebGPU
            ],
            nextInChain: nil
        )

        let texture = device.createTexture(descriptor: textureDesc)
        if let image = descriptor.image {
            let origin = WebGPU.Origin3d(x: 0, y: 0, z: 0)
            let writeSize = WebGPU.Extent3d(
                width: UInt32(image.width),
                height: UInt32(image.height),
                depthOrArrayLayers: 1
            )

            let bytesPerRow = descriptor.pixelFormat.bytesPerComponent * image.width

            unsafe image.data.withUnsafeBytes { buffer in
                unsafe precondition(buffer.baseAddress != nil, "Image should not contains empty address.")

                unsafe device.queue.writeTexture(
                    destination: TexelCopyTextureInfo(
                        texture: texture,
                        mipLevel: 0,
                        origin: origin,
                        aspect: TextureAspect.all
                    ),
                    data: buffer,
                    dataLayout: TexelCopyBufferLayout(
                        offset: 0,
                        bytesPerRow: UInt32(bytesPerRow),
                        rowsPerImage: UInt32(image.height)
                    ),
                    writeSize: writeSize
                )
            }
        }

        self.texture = texture
        self.textureView = texture.createView(
        //     descriptor: WebGPU.TextureViewDescriptor(
        //             label: descriptor.debugLabel, 
        //             format: descriptor.pixelFormat.toWebGPU, 
        //             dimension: descriptor.textureType.toWebGPUTextureViewDimension, 
        //             baseMipLevel: 0, 
        //             mipLevelCount: 0, 
        //             baseArrayLayer: 0, 
        //             arrayLayerCount: 0, 
        //             aspect: .all, 
        //             usage: wgpuUsage
        //         )
        )
    }

    // TODO: (Vlad) think about it later
    func getImage(device: WebGPU.Device) -> Image? {
        let imageFormat: Image.Format
        let bytesInPixel: UInt32

        switch self.texture.format {
        case .bgra8Unorm:
            imageFormat = .bgra8
            bytesInPixel = 4
        default:
            imageFormat = .rgba8
            bytesInPixel = 4
        }

        let bytesPerRow = self.texture.width * bytesInPixel
        let pixelCount = UInt32(self.texture.width * self.texture.height)
        let count = Int(pixelCount * bytesInPixel)
        var imageBytes = [UInt8](repeating: 0, count: count)
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 0)
//        unsafe self.texture.getBytes(
//            &imageBytes,
//            bytesPerRow: bytesPerRow,
//            from: MTLRegion(
//                origin: MTLOrigin(x: 0, y: 0, z: 0),
//                size: MTLSize(width: self.texture.width, height: self.texture.height, depth: 1)
//            ),
//            mipmapLevel: 0
//        )

        return unsafe Image(
            width: Int(self.texture.width),
            height: Int(self.texture.height),
            data: Data(bytesNoCopy: pointer, count: count, deallocator: .free),
            format: imageFormat
        )
    }
}

extension PixelFormat {
    var toWebGPU: WebGPU.TextureFormat {
        switch self {
        case .none:
                .undefined
        case .bgra8:
                .bgra8Unorm
        case .bgra8_srgb:
                .bgra8UnormSrgb
        case .rgba8:
                .rgba8Unorm
        case .rgba_16f:
                .rgba16Unorm
        case .rgba_32f:
                .rgba32Float
        case .depth_32f_stencil8:
                .depth32FloatStencil8
        case .depth_32f:
                .depth32Float
        case .depth24_stencil8:
                .depth24PlusStencil8
        }
    }
}

extension Texture.TextureType {
    var toWebGPUTextureDimension: WebGPU.TextureDimension {
        switch self {
        case .textureCube:
                .typeUndefined
        case .texture1D:
                .type1d
        case .texture1DArray:
                .type1d
        case .texture2D:
                .type2d
        case .texture2DArray:
                .type2d
        case .texture2DMultisample:
                .type2d
        case .texture2DMultisampleArray:
                .type2d
        case .texture3D:
                .type3d
        case .textureBuffer:
                .typeUndefined
        }
    }

    var toWebGPUTextureViewDimension: WebGPU.TextureViewDimension {
        switch self {
        case .textureCube:
                .typeUndefined
        case .texture1D:
                .type1d
        case .texture1DArray:
                .type1d
        case .texture2D:
                .type2d
        case .texture2DArray:
                .type2d
        case .texture2DMultisample:
                .type2d
        case .texture2DMultisampleArray:
                .type2d
        case .texture3D:
                .type3d
        case .textureBuffer:
                .typeUndefined
        }
    }
}

#endif
