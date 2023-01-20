//
//  Texture.swift
//  
//
//  Created by v.prusakov on 6/28/22.
//

import Foundation

open class Texture: Resource {
    
    private(set) var rid: RID
    private(set) var textureType: TextureType
    
    init(rid: RID, textureType: TextureType) {
        self.rid = rid
        self.textureType = textureType
    }
    
    deinit {
        self.freeTexture()
    }
    
    /// This method remove texture from GPU.
    ///
    /// - Warning: You should not use it method directly, this called once when Resource deinited from memory
    /// In some cases we shouldn't release texture from GPU memory, than we need override this method
    /// with empty realisation.
    func freeTexture() {
        RenderEngine.shared.removeTexture(by: self.rid)
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
