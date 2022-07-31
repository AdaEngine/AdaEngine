//
//  TextureAtlas.swift
//  
//
//  Created by v.prusakov on 6/30/22.
//

import Foundation
import Math

/// The atlas, also know as Sprite Sheet is an object contains an image and can provide
/// a little piece of the texture for specific stride. You can describe size of sprite you expect and grab specific sprite by coordinates.
/// The Atlas is more efficient way to use 2D textures, because the GPU works with one piece of data.
public final class TextureAtlas: Texture2D {
    
    private let spriteSize: Size
    
    /// For unpacked sprite sheets we should use margins between sprites to fit slice into correct coordinates.
    public var margin: Size
    
    /// Create a texture atlas.
    /// - Parameter image: The image from atlas will build.
    /// - Parameter size: The sprite size in atlas (in pixels).
    /// - Parameter margin: The margin between sprites (in pixels).
    public init(from image: Image, size: Size, margin: Size = .zero) {
        self.spriteSize = size
        self.margin = margin
        
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
    
    /// Create a slice of the texture.
    public subscript(x: Float, y: Float) -> Slice {
        return self.textureSlice(at: Vector2(x: x, y: y))
    }
    
    /// Create a slice of the texture.
    public func textureSlice(at position: Vector2) -> Slice {
        let min = Vector2(
            (position.x * (spriteSize.width + margin.width)) / Float(self.width),
            (position.y * (spriteSize.height + margin.height)) / Float(self.height)
        )
        
        let max = Vector2(
            ((position.x + 1) * (spriteSize.width + margin.width)) / Float(self.width),
            ((position.y + 1) * (spriteSize.height + margin.height)) / Float(self.height)
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
    
    /// A slice represents piece of the texture region. The slices is an efficient way to work with the texture.
    final class Slice: Texture2D {
        
        // We should store reference to the atlas, because if the altas deiniting from memory
        // then the GPU representation will be also deinited.
        // This also doesn't has reference cycle here, because the atlas don't store slices.
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
