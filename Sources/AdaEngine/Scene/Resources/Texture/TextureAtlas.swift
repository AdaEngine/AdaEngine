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
        
        super.init(image: image)
    }
    
    // MARK: - Resource
    
    struct TextureAtlasAssetRepresentation: Codable {
        let filePath: String
        let spriteSize: Size
        let margin: Size
    }
    
    public required init(asset decoder: AssetDecoder) throws {
        guard decoder.assetMeta.filePath.pathExtension == Self.resourceType.fileExtenstion else {
            throw AssetDecodingError.invalidAssetExtension(decoder.assetMeta.filePath.pathExtension)
        }
        
        let atlas = try decoder.decode(TextureAtlasAssetRepresentation.self)
        
        self.margin = atlas.margin
        self.spriteSize = atlas.spriteSize
        
        let image = try ResourceManager.load(atlas.filePath) as Image
        
        super.init(image: image)
    }
    
    public override func encodeContents(with encoder: AssetEncoder) throws {
        guard encoder.assetMeta.filePath.pathExtension == Self.resourceType.fileExtenstion else {
            throw AssetDecodingError.invalidAssetExtension(encoder.assetMeta.filePath.pathExtension)
        }
        
        let atlas = TextureAtlasAssetRepresentation(
            filePath: self.resourcePath,
            spriteSize: self.spriteSize,
            margin: self.margin
        )
        
        try encoder.encode(atlas)
    }
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case margin
        case spriteSize
        case resource
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.margin = try container.decode(Size.self, forKey: .margin)
        self.spriteSize = try container.decode(Size.self, forKey: .spriteSize)
        
        let path = try container.decode(String.self, forKey: .resource)
        let image = try ResourceManager.load(path) as Image
        
        super.init(image: image)
        
        let context = decoder.userInfo[.assetsDecodingContext] as? AssetDecodingContext
        context?.appendResource(self)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.margin, forKey: .margin)
        try container.encode(self.spriteSize, forKey: .spriteSize)
        try container.encode(self.resourcePath, forKey: .resource)
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
        // This also doesn't has reference cycle here, because the atlas doesn't store slices.
        public private(set) var atlas: TextureAtlas
        
        private let min: Vector2
        private let max: Vector2
        
        required init(atlas: TextureAtlas, min: Vector2, max: Vector2, size: Size) {
            self.atlas = atlas
            self.max = max
            self.min = min
            
            super.init(gpuTexture: atlas.gpuTexture, size: size)
            
            self.textureCoordinates = [
                [min.x, max.y],
                [max.x, max.y],
                [max.x, min.y],
                [min.x, min.y]
            ]
        }
        
        // MARK: - Resource
        
        struct AssetError: LocalizedError {
            var errorDescription: String? {
                "Couldn't use texture slice as asset."
            }
        }
        
        public required init(asset decoder: AssetDecoder) throws {
            throw AssetError()
        }
        
        public override func encodeContents(with encoder: AssetEncoder) throws {
            throw AssetError()
        }
        
        // MARK: - Codable
        
        enum CodingKeys: CodingKey {
            case textureAtlasResource
            case min
            case max
            case size
        }
        
        public convenience required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let path = try container.decode(String.self, forKey: .textureAtlasResource)
            let min = try container.decode(Vector2.self, forKey: .min)
            let max = try container.decode(Vector2.self, forKey: .max)
            let size = try container.decode(Size.self, forKey: .size)
            
            guard let context = decoder.userInfo[.assetsDecodingContext] as? AssetDecodingContext else {
                fatalError()
            }
            
            guard let atlas = context.getResource(at: path) as TextureAtlas? else {
                fatalError()
            }
            
            self.init(atlas: atlas, min: min, max: max, size: size)
        }
        
        public override func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.atlas.resourcePath, forKey: .textureAtlasResource)
            try container.encode(self.min, forKey: .min)
            try container.encode(self.max, forKey: .max)
            try container.encode(Size(width: Float(self.width), height: Float(self.height)), forKey: .size)
        }
    }
}
