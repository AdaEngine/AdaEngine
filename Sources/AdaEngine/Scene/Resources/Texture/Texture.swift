//
//  Texture.swift
//  
//
//  Created by v.prusakov on 6/28/22.
//

open class Texture: Resource, Codable {
    
    private(set) var gpuTexture: GPUTexture
    public private(set) var sampler: Sampler
    private(set) var textureType: TextureType
    
    public var resourcePath: String = ""
    public var resourceName: String = ""
    
    init(gpuTexture: GPUTexture, sampler: Sampler, textureType: TextureType) {
        self.gpuTexture = gpuTexture
        self.textureType = textureType
        self.sampler = sampler
    }
    
    public required init(from decoder: Decoder) throws {
        fatalError()
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError()
    }
    
    // MARK: - Resources
    
    public required init(asset decoder: AssetDecoder) throws {
        fatalError()
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalError()
    }
    
    public static let resourceType: ResourceType = .texture
}

public extension Texture {
    enum TextureType: UInt16, Codable {
        case texture1D
        case texture1DArray
        case texture2D
        case texture2DArray
        case texture2DMultisample
        case texture2DMultisampleArray
        
        case textureCube
        case texture3D
        case textureBuffer
    }
    
    struct Usage: OptionSet, Codable {
        
        public typealias RawValue = UInt8
        
        public var rawValue: UInt8
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
        
        public static var read = Usage(rawValue: 1 << 0)
        public static var write = Usage(rawValue: 1 << 1)
        public static var renderTarget = Usage(rawValue: 1 << 2)
    }
}
