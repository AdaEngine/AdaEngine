//
//  RenderTexture.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/28/23.
//

// FIXME: (Vlad) should say that texture isn't use for rendering anymore
// FIXME: (Vlad) I feel that we have a bug with deinitialization here

import Math

// A texture using as a render target.
public final class RenderTexture: Texture2D, @unchecked Sendable {
    
    public let pixelFormat: PixelFormat
    public let scaleFactor: Float
    
    public private(set) var isActive: Bool = true
    
    public init(size: SizeInt, scaleFactor: Float, format: PixelFormat, debugLabel: String? = nil) {
        let descriptor = TextureDescriptor(
            width: size.width,
            height: size.height,
            pixelFormat: format,
            textureUsage: [.renderTarget, .read],
            textureType: .texture2D,
            debugLabel: debugLabel
        )

        self.pixelFormat = format
        self.scaleFactor = scaleFactor
        
        let device = RenderEngine.shared.renderDevice
        let gpuTexture = device.createTexture(from: descriptor)
        let sampler = device.createSampler(from: descriptor.samplerDescription)
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, size: size)
    }

    public required init(from decoder: AssetDecoder) throws {
        fatalError("init(asset:) has not been implemented")
    }
    
    func setActive(_ isActive: Bool) {
        self.isActive = isActive
    }
}
