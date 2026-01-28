//
//  MetalBlitCommandEncoder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

#if canImport(WebGPU)
import Foundation
import WebGPU
import CWebGPU

final class WGPUBlitCommandEncoder: BlitCommandEncoder {
    let blitEncoder: WebGPU.CommandEncoder
    let device: WebGPU.Device

    init(
        blitEncoder: WebGPU.CommandEncoder,
        device: WebGPU.Device
    ) {
        self.blitEncoder = blitEncoder
        self.device = device
    }

    func pushDebugName(_ string: String) {
        blitEncoder.pushDebugGroup(groupLabel: string)
    }

    func popDebugName() {
        blitEncoder.popDebugGroup()
    }

    func copyTextureToTexture(
        source: Texture,
        sourceOrigin: Origin3D,
        sourceSize: Size3D,
        sourceMipLevel: Int,
        sourceSlice: Int,
        destination: Texture,
        destinationOrigin: Origin3D,
        destinationMipLevel: Int,
        destinationSlice: Int
    ) {
        guard
            let src = source.gpuTexture as? WGPUGPUTexture,
            let dst = destination.gpuTexture as? WGPUGPUTexture
        else { fatalError("Textures must be WGPU textures") }

        blitEncoder.copyTextureToTexture(
            source: TexelCopyTextureInfo(
                texture: src.texture, 
                mipLevel: UInt32(sourceMipLevel), 
                origin: Origin3d(x: UInt32(sourceOrigin.x), y: UInt32(sourceOrigin.y), z: UInt32(sourceOrigin.z)), 
                aspect: TextureAspect.all
            ), 
            destination: TexelCopyTextureInfo(
                texture: dst.texture,
                mipLevel: UInt32(destinationMipLevel), 
                origin: Origin3d(x: UInt32(destinationOrigin.x), y: UInt32(destinationOrigin.y), z: UInt32(destinationOrigin.z)), 
                aspect: TextureAspect.all
            ), 
            copySize: Extent3d(
                width: UInt32(sourceSize.width), 
                height: UInt32(sourceSize.height), 
                depthOrArrayLayers: 1
            )
        )
    }

    func copyBufferToBuffer(
        source: Buffer,
        sourceOffset: Int,
        destination: Buffer,
        destinationOffset: Int,
        size: Int
    ) {
        guard
            let src = source as? WGPUBuffer,
            let dst = destination as? WGPUBuffer
        else { fatalError("Buffers must be WGPU buffers") }
        blitEncoder.copyBufferToBuffer(
            source: src.buffer, 
            sourceOffset: UInt64(sourceOffset), 
            destination: dst.buffer, 
            destinationOffset: UInt64(destinationOffset), 
            size: UInt64(size)
        )
    }

    func copyBufferToTexture(
        source: Buffer,
        sourceOffset: Int,
        sourceBytesPerRow: Int,
        sourceBytesPerImage: Int,
        sourceSize: Size3D,
        destination: Texture,
        destinationOrigin: Origin3D,
        destinationMipLevel: Int,
        destinationSlice: Int
    ) {
        guard
            let src = source as? WGPUBuffer,
            let dst = destination.gpuTexture as? WGPUGPUTexture
        else { fatalError("Invalid WGPU resources") }

        blitEncoder.copyBufferToTexture(
            source: TexelCopyBufferInfo(
                layout: TexelCopyBufferLayout(
                    offset: UInt64(sourceOffset), 
                    bytesPerRow: UInt32(sourceBytesPerRow), 
                    rowsPerImage: UInt32(sourceBytesPerImage)), 
                    buffer: src.buffer
                ), 
            destination: TexelCopyTextureInfo(
                texture: dst.texture, 
                mipLevel: UInt32(destinationMipLevel), 
                origin: Origin3d(x: UInt32(destinationOrigin.x), y: UInt32(destinationOrigin.y), z: UInt32(destinationOrigin.z)), 
                aspect: TextureAspect.all
            ), 
            copySize: Extent3d(
                width: UInt32(sourceSize.width), 
                height: UInt32(sourceSize.height), 
                depthOrArrayLayers: 1
            )
        )
    }

    func copyTextureToBuffer(
        source: Texture,
        sourceOrigin: Origin3D,
        sourceMipLevel: Int,
        sourceSlice: Int,
        sourceSize: Size3D,
        destination: Buffer,
        destinationOffset: Int,
        destinationBytesPerRow: Int,
        destinationBytesPerImage: Int
    ) {
        guard
            let src = source.gpuTexture as? WGPUGPUTexture,
            let dst = destination as? WGPUBuffer
        else { fatalError("Invalid WGPU resources") }

        blitEncoder.copyTextureToBuffer(
            source: TexelCopyTextureInfo(
                texture: src.texture, 
                mipLevel: UInt32(sourceMipLevel), 
                origin: Origin3d(x: UInt32(sourceOrigin.x), y: UInt32(sourceOrigin.y), z: UInt32(sourceOrigin.z)), 
                aspect: TextureAspect.all
            ), 
            destination: TexelCopyBufferInfo(
                layout: TexelCopyBufferLayout(
                    offset: UInt64(destinationOffset), 
                    bytesPerRow: UInt32(destinationBytesPerRow), 
                    rowsPerImage: UInt32(destinationBytesPerImage)), 
                    buffer: dst.buffer
                ), 
            copySize: Extent3d(
                width: UInt32(sourceSize.width), 
                height: UInt32(sourceSize.height), 
                depthOrArrayLayers: 1
            )
        )
    }

    func endBlitPass() { }
}
#endif
