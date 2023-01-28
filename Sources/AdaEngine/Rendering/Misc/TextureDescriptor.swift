//
//  TextureDescriptor.swift
//  
//
//  Created by v.prusakov on 1/25/23.
//

public struct TextureDescriptor {
    public var width: Int = 1
    public var height: Int = 1
    public var pixelFormat: PixelFormat = .bgra8
    public var textureUsage: Texture.Usage
    public var textureType: Texture.TextureType
    public var mipmapLevel: Int = 0
    
    public var image: Image?
}
