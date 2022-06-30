//
//  Texture.swift
//  
//
//  Created by v.prusakov on 6/28/22.
//

import Foundation

public class Texture {
    
    private(set) var rid: RID
    private(set) var textureType: TextureType
    
    init(rid: RID, textureType: TextureType) {
        self.rid = rid
        self.textureType = textureType
    }
}

public extension Texture {
    enum TextureType: UInt16, Codable {
        case cube
        case texture2D
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
        public static var render = Usage(rawValue: 1 << 2)
    }
}
