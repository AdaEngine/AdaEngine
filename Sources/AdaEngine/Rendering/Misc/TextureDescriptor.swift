//
//  TextureDescriptor.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/25/23.
//

/// An object that you use to configure new texture objects.
public struct TextureDescriptor {
    
    /// The width of the texture image for the base level mipmap, in pixels.
    public var width: Int
    
    /// The height of the texture image for the base level mipmap, in pixels.
    public var height: Int
    
    /// The size and bit layout of all pixels in the texture.
    public var pixelFormat: PixelFormat
    
    /// Options that determine how you can use the texture.
    public var textureUsage: Texture.Usage
    
    /// The dimension and arrangement of texture image data.
    public var textureType: Texture.TextureType
    
    /// The number of mipmap levels for this texture.
    public var mipmapLevel: Int
    
    /// The data from we can create a texture.
    public var image: Image?
    
    /// The sampler that describe how to render a texture.
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

/// Interface represent platform specific gpu texture.
public class GPUTexture { }
