//
//  Texture.swift
//  
//
//  Created by v.prusakov on 6/28/22.
//

import Foundation

open class Texture: Resource, Codable {
    
    private(set) var gpuTexture: GPUTexture
    private(set) var textureType: TextureType
    
    public var resourcePath: String = ""
    public var resourceName: String = ""
    
    init(gpuTexture: GPUTexture, textureType: TextureType) {
        self.gpuTexture = gpuTexture
        self.textureType = textureType
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
        case cube
        case texture2D
        case texture2DArray
        case texture3D
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
