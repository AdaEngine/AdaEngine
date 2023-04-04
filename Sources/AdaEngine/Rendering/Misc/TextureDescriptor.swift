//
//  TextureDescriptor.swift
//  
//
//  Created by v.prusakov on 1/25/23.
//

public struct TextureDescriptor {
    public var width: Int
    public var height: Int
    public var pixelFormat: PixelFormat
    public var textureUsage: Texture.Usage
    public var textureType: Texture.TextureType
    public var mipmapLevel: Int
    
    public var image: Image?
    
    public var samplerDescription: SamplerDescriptor
    
    public init(
        width: Int = 1,
        height: Int = 1,
        pixelFormat: PixelFormat = .bgra8,
        textureUsage: Texture.Usage,
        textureType: Texture.TextureType,
        mipmapLevel: Int = 0,
        image: Image? = nil,
        samplerDescription: SamplerDescriptor = SamplerDescriptor()
    ) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.textureUsage = textureUsage
        self.textureType = textureType
        self.mipmapLevel = mipmapLevel
        self.image = image
        self.samplerDescription = samplerDescription
    }
}

public class GPUTexture { }
