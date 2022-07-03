//
//  TextureAtlas.swift
//  
//
//  Created by v.prusakov on 6/30/22.
//

import Foundation
import Math

public final class TextureAtlas: Texture2D {
    
    private let spriteSize: Size
    
    public init(from image: Image, size: Size) {
        self.spriteSize = size
        
        super.init(from: image)
    }
    
    // MARK: - Resource
    
    public required init(assetFrom data: Data) async throws {
        fatalError()
    }

    public override func encodeContents() async throws -> Data {
        fatalError()
    }
    
    // MARK: - Slices
    
    public subscript(x: Float, y: Float) -> Slice {
        return self.textureSlice(at: Vector2(x: x, y: y))
    }
    
    /// Create slice of texture referenced on 
    public func textureSlice(at position: Vector2) -> Slice {
        let min = Vector2(
            (position.x * spriteSize.width) / Float(self.width),
            (position.y * spriteSize.height) / Float(self.height)
        )
        
        let max = Vector2(
            ((position.x + 1) * spriteSize.width) / Float(self.width),
            ((position.y + 1) * spriteSize.height) / Float(self.height)
        )
        
        return Slice(
            atlas: self,
            min: min,
            max: max,
            size: self.spriteSize
        )
    }
    
}

public extension TextureAtlas {
    
    /// Slice from texture atlas needed to reference on specific texture.
    final class Slice: Texture2D {
        
        // we should store ref to atlas, because if altas deiniting from memory
        // that gpu representation will also deinited.
        // that also doesn't have ref cycles here, because atlas don't store slices.
        public private(set) var atlas: TextureAtlas
        
        required init(atlas: TextureAtlas, min: Vector2, max: Vector2, size: Size) {
            self.atlas = atlas
            
            super.init(rid: atlas.rid, size: size)
            
            self.textureCoordinates = [
                [min.x, max.y],
                [max.x, max.y],
                [max.x, min.y],
                [min.x, min.y]
            ]
        }
        
        override func freeTexture() {
            // we should not release atlas
        }
        
        public required init(assetFrom data: Data) async throws {
            fatalError("You cannot load slice from asset.")
        }
        
        public override func encodeContents() async throws -> Data {
            fatalError("You cannot save slice to asset")
        }
    }
}
