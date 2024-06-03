//
//  Texture2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/28/22.
//

import Math

/// The base class represents a 2D texture.
/// If the texture isn't held by any object, then the GPU resource will freed immediately.
open class Texture2D: Texture {
    
    public private(set) var width: Int
    public private(set) var height: Int
    
    public var size: SizeInt {
        return SizeInt(width: self.width, height: self.height)
    }
    
    public init(image: Image, samplerDescription: SamplerDescriptor? = nil) {
        let descriptor = TextureDescriptor(
            width: image.width,
            height: image.height,
            pixelFormat: image.format.toPixelFormat,
            textureUsage: [.read],
            textureType: .texture2D,
            image: image,
            samplerDescription: samplerDescription ?? image.samplerDescription
        )
        
        let gpuTexture = RenderEngine.shared.makeTexture(from: descriptor)
        let sampler = RenderEngine.shared.makeSampler(from: descriptor.samplerDescription)
        
        self.width = descriptor.width
        self.height = descriptor.height
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, textureType: descriptor.textureType)
        self.resourceMetaInfo = image.resourceMetaInfo
    }
    
    public init(descriptor: TextureDescriptor) {
        let gpuTexture = RenderEngine.shared.makeTexture(from: descriptor)
        let sampler = RenderEngine.shared.makeSampler(from: descriptor.samplerDescription)
        
        self.width = descriptor.width
        self.height = descriptor.height
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, textureType: descriptor.textureType)
    }
    
    // FIXME: (Vlad) Should remove it from Texture2D.
    open internal(set) var textureCoordinates: [Vector2] = [
        [0, 1], [1, 1], [1, 0], [0, 0]
    ]
    
    internal init(gpuTexture: GPUTexture, sampler: Sampler, size: SizeInt) {
        self.width = size.width
        self.height = size.height
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, textureType: .texture2D)
    }
    
    // MARK: - Resource & Codable
    
    enum CodingKeys: String, CodingKey {
        case sampler
        case filePath = "file"
    }
    
    public required init(asset decoder: any AssetDecoder) async throws {
        let texture = try decoder.decode(Self.self)
        self.width = texture.width
        self.height = texture.height
        
        super.init(gpuTexture: texture.gpuTexture, sampler: texture.sampler, textureType: texture.textureType)
    }
    
    public convenience required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let filePath = try container.decode(ResourceMetaInfo.self, forKey: .filePath)
        let samplerDesc = try container.decodeIfPresent(SamplerDescriptor.self, forKey: .sampler)
        
        let image = try decoder.assetsDecodingContext.getOrLoadResource(at: filePath.fullFileURL.absoluteString) as Image
        self.init(image: image, samplerDescription: samplerDesc)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.resourceMetaInfo, forKey: .filePath)
        try container.encode(self.sampler.descriptor, forKey: .sampler)
    }
}

public extension Texture2D {
    static let whiteTexture = Texture2D(image: Image(width: 1, height: 1, color: .white))
}
