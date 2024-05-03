//
//  Texture2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/28/22.
//

/// The base class represents a 2D texture.
/// If the texture isn't held by any object, then the GPU resource will freed immediately.
open class Texture2D: Texture {
    
    public private(set) var width: Int
    public private(set) var height: Int
    
    public init(image: Image) {
        let descriptor = TextureDescriptor(
            width: image.width,
            height: image.height,
            pixelFormat: image.format.toPixelFormat,
            textureUsage: [.read],
            textureType: .texture2D,
            image: image,
            samplerDescription: image.samplerDescription
        )
        
        let gpuTexture = RenderEngine.shared.makeTexture(from: descriptor)
        let sampler = RenderEngine.shared.makeSampler(from: descriptor.samplerDescription)
        
        self.width = descriptor.width
        self.height = descriptor.height
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, textureType: descriptor.textureType)
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
    
    internal init(gpuTexture: GPUTexture, sampler: Sampler, size: Size) {
        self.width = Int(size.width)
        self.height = Int(size.height)
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, textureType: .texture2D)
    }
    
    // MARK: - Codable
    
    // TODO: Add Sampler support
    public convenience required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let path = try container.decode(String.self)
        
        let image = try ResourceManager.loadSync(path) as Image
        self.init(image: image)
        
        let context = decoder.userInfo[.assetsDecodingContext] as? AssetDecodingContext
        context?.appendResource(self)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if self.resourcePath.isEmpty {
            try container.encode(self.resourcePath)
            return
        }
        
        try container.encode(self.resourcePath)
    }
    
    // MARK: - Resource
    
    public required init(asset decoder: AssetDecoder) async throws {
        let image = try Image(asset: decoder)
        
        let descriptor = TextureDescriptor(
            width: image.width,
            height: image.height,
            pixelFormat: image.format.toPixelFormat,
            textureUsage: [.read],
            textureType: .texture2D,
            image: image
        )
        
        let gpuTexture = RenderEngine.shared.makeTexture(from: descriptor)
        let sampler = RenderEngine.shared.makeSampler(from: SamplerDescriptor())
        
        self.width = image.width
        self.height = image.height
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, textureType: .texture2D)
    }
    
    public override func encodeContents(with encoder: AssetEncoder) async throws {

    }
}

public extension Texture2D {
    static let whiteTexture = Texture2D(image: Image(width: 1, height: 1, color: .white))
}
