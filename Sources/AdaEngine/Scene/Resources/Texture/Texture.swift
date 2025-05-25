//
//  Texture.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/28/22.
//

/// Base class describing a texture.
open class Texture: Asset, Codable, @unchecked Sendable {
    
    private(set) var gpuTexture: GPUTexture
    
    /// The sampler instance that describe how to render texture.
    public private(set) var sampler: Sampler
    
    private(set) var textureType: TextureType
    
    public var assetMetaInfo: AssetMetaInfo?
    
    init(gpuTexture: GPUTexture, sampler: Sampler, textureType: TextureType) {
        self.gpuTexture = gpuTexture
        self.textureType = textureType
        self.sampler = sampler
    }
    
    /// Returns an ``Image`` instance.
    public var image: Image {
        if let image = RenderEngine.shared.renderDevice.getImage(from: self) {
            return image
        }
        
        return Image()
    }
    
    public required init(asset decoder: any AssetDecoder) async throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func encodeContents(with encoder: any AssetEncoder) async throws {
        fatalErrorMethodNotImplemented()
    }
    
    public required init(from decoder: Decoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public static func extensions() -> [String] {
        return ["tex"]
    }

    public func update(_ newAsset: Texture) async throws {
        self.gpuTexture = newAsset.gpuTexture
        self.sampler = newAsset.sampler
        self.textureType = newAsset.textureType
    }
}

public extension Texture {
    
    /// The dimension of each image, including whether multiple images are arranged into an array or a cube.
    enum TextureType: UInt16, Codable, Sendable {
        
        /// A one-dimensional texture image.
        case texture1D
        
        /// An array of one-dimensional texture images.
        case texture1DArray
        
        /// A two-dimensional texture image.
        case texture2D
        
        /// An array of two-dimensional texture images.
        case texture2DArray
        
        /// A two-dimensional texture image that uses more than one sample for each pixel.
        case texture2DMultisample
        
        /// An array of two-dimensional texture images that use more than one sample for each pixel.
        case texture2DMultisampleArray
        
        /// A cube texture with six two-dimensional images.
        case textureCube
        
        /// A three-dimensional texture image.
        case texture3D
        
        /// A texture buffer.
        case textureBuffer
    }
    
    /// An enumeration for the various options that determine how you can use a texture.
    struct Usage: OptionSet, Codable, Sendable {
        
        public typealias RawValue = UInt8
        
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// An option for reading or sampling from the texture in a shader.
        public static let read = Usage(rawValue: 1 << 0)
        
        /// An option for writing to the texture in a shader.
        public static let write = Usage(rawValue: 1 << 1)
        
        /// An option for rendering to the texture in a render pass.
        public static let renderTarget = Usage(rawValue: 1 << 2)
    }
}

// MARK: - RuntimeRegistrable

@_spi(Runtime)
extension Texture: RuntimeRegistrable {
    
    @MainActor static private(set) var types: [String: Texture.Type] = [:]
    
    @MainActor
    static func registerTextureType() {
        types[String(reflecting: type(of: self))] = Self.self
    }
    
    @MainActor
    public static func registerTypes() {
        AssetsManager.registerAssetType(Texture2D.self)
        AssetsManager.registerAssetType(TextureAtlas.self)
        AssetsManager.registerAssetType(TextureAtlas.Slice.self)
        AssetsManager.registerAssetType(AnimatedTexture.self)
        
        Texture2D.registerTextureType()
        TextureAtlas.registerTextureType()
        AnimatedTexture.registerTextureType()
    }
}
