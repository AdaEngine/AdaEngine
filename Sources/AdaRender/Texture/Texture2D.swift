//
//  Texture2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/28/22.
//

import AdaAssets
import AdaUtils
import Math

/// The base class represents a 2D texture.
/// If the texture isn't held by any object, then the GPU resource will freed immediately.
open class Texture2D: Texture, @unchecked Sendable {
    
    /// The width of the texture.
    public private(set) var width: Int
    /// The height of the texture.
    public private(set) var height: Int
    
    /// The size of the texture.
    public var size: SizeInt {
        return SizeInt(width: self.width, height: self.height)
    }
    
    /// Initialize a new texture from an image.
    ///
    /// - Parameters:
    ///   - image: The image to initialize the texture from.
    ///   - samplerDescription: The sampler description of the texture.
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
    
    /// Initialize a new texture from a descriptor.
    ///
    /// - Parameter descriptor: The descriptor to initialize the texture from.
    public init(descriptor: TextureDescriptor) {
        let device = RenderEngine.shared.createLocalRenderDevice()
        let gpuTexture = device.createTexture(from: descriptor)
        let sampler = device.createSampler(from: descriptor.samplerDescription)

        self.width = descriptor.width
        self.height = descriptor.height
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, textureType: descriptor.textureType)
    }
    
    // FIXME: (Vlad) Should remove it from Texture2D.
    /// The texture coordinates.
    open internal(set) var textureCoordinates: [Vector2] = [
        [0, 1], [1, 1], [1, 0], [0, 0]
    ]
    
    internal init(gpuTexture: GPUTexture, sampler: Sampler, size: SizeInt) {
        self.width = size.width
        self.height = size.height
        
        super.init(gpuTexture: gpuTexture, sampler: sampler, textureType: .texture2D)
    }
    
    // MARK: - Resource & Codable
    
    /// Initialize a new texture from a decoder.
    ///
    /// - Parameter decoder: The decoder to initialize the texture from.
    /// - Throws: An error if the texture cannot be initialized from the decoder.
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
    
    /// Encode the texture to an encoder.
    ///
    /// - Parameter encoder: The encoder to encode the texture to.
    /// - Throws: An error if the texture cannot be encoded to the encoder.
    public override func encodeContents(with encoder: any AssetEncoder) throws {
        try encoder.encode(
            TextureSerializable(
                info: self.assetMetaInfo,
                sampler: self.sampler.descriptor
            )
        )
    }
}

public extension Texture2D {
    /// A white texture.
    static let whiteTexture = Texture2D(image: Image(width: 1, height: 1, color: .white))
}

extension Texture2D {
    struct TextureSerializable: Codable {
        let info: AssetMetaInfo?
        let sampler: SamplerDescriptor
    }
}
