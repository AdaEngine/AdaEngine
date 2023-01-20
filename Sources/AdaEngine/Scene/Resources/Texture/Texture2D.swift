//
//  Texture2D.swift
//  
//
//  Created by v.prusakov on 6/28/22.
//

import Foundation
import Yams

/// The base class represents a 2D texture.
/// If the texture isn't held by any object, then the GPU resource will freed immediately.
open class Texture2D: Texture {
    
    public private(set) var width: Float
    public private(set) var height: Float
    
    public init(from image: Image) {
        let rid = RenderEngine.shared.makeTexture(from: image, type: .texture2D, usage: [.read, .renderTarget])
        
        self.width = Float(image.width)
        self.height = Float(image.height)
        
        super.init(rid: rid, textureType: .texture2D)
    }
    
    public var image: Image? {
        RenderEngine.shared.getImage(for: self.rid)
    }
    
    open internal(set) var textureCoordinates: [Vector2] = [
        [0, 1], [1, 1], [1, 0], [0, 0]
    ]
    
    internal init(rid: RID, size: Size) {
        self.width = size.width
        self.height = size.height
        
        super.init(rid: rid, textureType: .texture2D)
    }
    
    // MARK: - Resource
    
    public required init(asset decoder: AssetDecoder) throws {
        let image = try Image(asset: decoder)
        
        let rid = RenderEngine.shared.makeTexture(
            from: image,
            type: .texture2D,
            usage: [.read]
        )
        
        self.width = Float(image.width)
        self.height = Float(image.height)
        
        super.init(rid: rid, textureType: .texture2D)
    }
    
    public override func encodeContents(with encoder: AssetEncoder) throws {
        try self.image?.encodeContents(with: encoder)
    }
}

// MARK: - Equatable

extension Texture2D: Equatable {
    public static func == (lhs: Texture2D, rhs: Texture2D) -> Bool {
        lhs.rid == rhs.rid &&
        lhs.height == rhs.height &&
        lhs.textureCoordinates == rhs.textureCoordinates
    }
}
