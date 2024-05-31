//
//  Texture.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/28/22.
//

/// Base class describing a texture.
open class Texture: Resource, Codable {
    
    private(set) var gpuTexture: GPUTexture
    
    /// The sampler instance that describe how to render texture.
    public private(set) var sampler: Sampler
    
    private(set) var textureType: TextureType
    
    public var resourcePath: String = ""
    public var resourceName: String = ""
    
    init(gpuTexture: GPUTexture, sampler: Sampler, textureType: TextureType) {
        self.gpuTexture = gpuTexture
        self.textureType = textureType
        self.sampler = sampler
    }
    
    /// Returns an ``Image`` instance.
    public var image: Image {
        if let image = RenderEngine.shared.getImage(from: self) {
            return image
        }
        
        return Image()
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TextureCodingKeys.self)
        self.textureType = try container.decode(TextureType.self, forKey: .textureType)
        
        fatalErrorMethodNotImplemented()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TextureCodingKeys.self)
        
        try container.encode(String(reflecting: Self.self), forKey: .classType)
        try container.encode(self.textureType, forKey: .textureType)
    }
    
    // MARK: - Resources
    
    public required init(asset decoder: AssetDecoder) async throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func encodeContents(with encoder: AssetEncoder) async throws {
        fatalErrorMethodNotImplemented()
    }
    
    public static let resourceType: ResourceType = .texture
}

public extension Texture {
    
    /// The dimension of each image, including whether multiple images are arranged into an array or a cube.
    enum TextureType: UInt16, Codable {
        
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
    struct Usage: OptionSet, Codable {
        
        public typealias RawValue = UInt8
        
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        /// An option for reading or sampling from the texture in a shader.
        public static var read = Usage(rawValue: 1 << 0)
        
        /// An option for writing to the texture in a shader.
        public static var write = Usage(rawValue: 1 << 1)
        
        /// An option for rendering to the texture in a render pass.
        public static var renderTarget = Usage(rawValue: 1 << 2)
    }
}

private extension Texture {
    
    enum TextureCodingKeys: String, CodingKey {
        case classType
        case textureType
    }
    
}

@_spi(Runtime)
extension Texture: RuntimeRegistrable {
    
    static private(set) var types: [String: Texture.Type] = [:]
    
    static func registerTextureType() {
        types[String(reflecting: self)] = Self.self
    }
    
    public static func registerTypes() {
        Texture2D.registerTextureType()
        TextureAtlas.registerTextureType()
    }
}
