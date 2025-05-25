//
//  Texture2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/28/22.
//

import Math

/// The base class represents a 2D texture.
/// If the texture isn't held by any object, then the GPU resource will freed immediately.
open class Texture2D: Texture, @unchecked Sendable {
    
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

        let device = RenderEngine.shared.createLocalRenderDevice()
        let gpuTexture = device.createTexture(from: descriptor)
        let sampler = device.createSampler(from: descriptor.samplerDescription)

        self.width = descriptor.width
        self.height = descriptor.height
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, textureType: descriptor.textureType)
        self.assetMetaInfo = image.assetMetaInfo
    }
    
    public init(descriptor: TextureDescriptor) {
        let device = RenderEngine.shared.createLocalRenderDevice()
        let gpuTexture = device.createTexture(from: descriptor)
        let sampler = device.createSampler(from: descriptor.samplerDescription)

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
    
    public convenience required init(from decoder: any AssetDecoder) throws {
        if Self.extensions().contains(where: { $0 == decoder.assetMeta.filePath.pathExtension }) {
            let dto = try decoder.decode(TextureSerializable.self)
            
            let filePath = dto.info?.assetAbsolutePath.path() ?? decoder.assetMeta.filePath.path()
            let samplerDesc = dto.sampler
            
            let image = try decoder.getOrLoadResource(
                Image.self,
                at: filePath
            )
            self.init(image: image.asset, samplerDescription: samplerDesc)
        } else {
            let image = try Image(from: decoder)
            self.init(image: image, samplerDescription: image.samplerDescription)
        }
    }
    
    public override func encodeContents(with encoder: any AssetEncoder) throws {
        try encoder.encode(
            TextureSerializable(
                info: self.assetMetaInfo,
                sampler: self.sampler.descriptor
            )
        )
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encodeIfPresent(self.assetMetaInfo, forKey: .filePath)
//        try container.encode(self.sampler.descriptor, forKey: .sampler)
    }
}

public extension Texture2D {
    static let whiteTexture = Texture2D(image: Image(width: 1, height: 1, color: .white))
}

extension Texture2D {
    struct TextureSerializable: Codable {
        let info: AssetMetaInfo?
        let sampler: SamplerDescriptor
    }
}
