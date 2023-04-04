//
//  RenderTexture.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/28/23.
//

// FIXME: (Vlad) should say that texture isn't use for rendering anymore
// FIXME: (Vlad) I feel that we have a bug with deinitialization here

// A texture using as a render target.
public class RenderTexture: Texture2D {
    
    public let pixelFormat: PixelFormat
    public let scaleFactor: Float
    
    public private(set) var isActive: Bool = true
    
    public init(size: Size, scaleFactor: Float, format: PixelFormat) {
        let descriptor = TextureDescriptor(
            width: Int(size.width),
            height: Int(size.height),
            pixelFormat: format,
            textureUsage: [.renderTarget, .read],
            textureType: .texture2D
        )
        
        self.pixelFormat = format
        self.scaleFactor = scaleFactor
        
        let gpuTexture = RenderEngine.shared.makeTexture(from: descriptor)
        let sampler = RenderEngine.shared.makeSampler(from: descriptor.samplerDescription)
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, size: size)
    }
    
    public required init(asset decoder: AssetDecoder) throws {
        fatalError("init(asset:) has not been implemented")
    }
    
    public convenience required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    func setActive(_ isActive: Bool) {
        self.isActive = isActive
    }
}
