//
//  TextureAtlas.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/30/22.
//

import Math

/// The atlas, also know as Sprite Sheet is an object contains an image and can provide
/// a little piece of the texture for specific stride. You can describe size of sprite you expect and grab specific sprite by coordinates.
/// The Atlas is more efficient way to use 2D textures, because the GPU works with one piece of data.
public final class TextureAtlas: Texture2D, @unchecked Sendable {
    
    private let spriteSize: SizeInt
    
    /// For unpacked sprite sheets we should use margins between sprites to fit slice into correct coordinates.
    public var margin: SizeInt
    
    /// Create a texture atlas.
    /// - Parameter image: The image from atlas will build.
    /// - Parameter size: The sprite size in atlas (in pixels).
    /// - Parameter margin: The margin between sprites (in pixels).
    public init(from image: Image, size: SizeInt, margin: SizeInt = .zero) {
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
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case margin
        case spriteSize
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.margin = try container.decode(SizeInt.self, forKey: .margin)
        self.spriteSize = try container.decode(SizeInt.self, forKey: .spriteSize)
        
        let superDecoder = try container.superDecoder()
        let texture = try Texture2D(from: superDecoder)
        
        super.init(gpuTexture: texture.gpuTexture, sampler: texture.sampler, size: texture.size)
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.margin, forKey: .margin)
        try container.encode(self.spriteSize, forKey: .spriteSize)
        
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }
    
    public required init(asset decoder: any AssetDecoder) async throws {
        let atlas = try decoder.decode(Self.self)
        self.spriteSize = atlas.spriteSize
        self.margin = atlas.margin
        
        super.init(
            gpuTexture: atlas.gpuTexture,
            sampler: atlas.sampler,
            size: [atlas.width, atlas.height]
        )
    }
    
    public override func encodeContents(with encoder: any AssetEncoder) async throws {
        try encoder.encode(self)
    }
    
    // MARK: - Slices
    
    /// Create a slice of the texture.
    public subscript(x: Int, y: Int) -> Slice {
        return self.textureSlice(at: PointInt(x: x, y: y))
    }
    
    /// Create a slice of the texture.
    public func textureSlice(at position: PointInt) -> Slice {
        let min = Vector2(
            (Float(position.x) * Float((spriteSize.width + margin.width))) / Float(self.width),
            (Float(position.y) * Float((spriteSize.height + margin.height))) / Float(self.height)
        )
        
        let max = Vector2(
            (Float(position.x + 1) * Float((spriteSize.width + margin.width))) / Float(self.width),
            (Float(position.y + 1) * Float((spriteSize.height + margin.height))) / Float(self.height)
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
    final class Slice: Texture2D, @unchecked Sendable {
        
        // We should store reference to the atlas, because if the altas deiniting from memory
        // then the GPU representation will be also deinited.
        // This also doesn't has reference cycle here, because the atlas doesn't store slices.
        public private(set) var atlas: TextureAtlas
        
        private let min: Vector2
        private let max: Vector2
        
        internal let position: Vector2
        
        required init(atlas: TextureAtlas, min: Vector2, max: Vector2, size: SizeInt) {
            self.atlas = atlas
            self.max = max
            self.min = min
            self.position = [min.x * Float(atlas.width), min.y * Float(atlas.height)]
            
            super.init(gpuTexture: atlas.gpuTexture, sampler: atlas.sampler, size: size)
            
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
        
        // MARK: - Codable
        
        enum CodingKeys: CodingKey {
            case textureAtlasResource
            case min
            case max
            case size
        }
        
        public required init(asset decoder: any AssetDecoder) async throws {
            fatalError("init(asset:) has not been implemented")
        }
        
        public convenience required init(from decoder: Decoder) throws {
            let context = decoder.assetsDecodingContext
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let path = try container.decode(String.self, forKey: .textureAtlasResource)
            let min = try container.decode(Vector2.self, forKey: .min)
            let max = try container.decode(Vector2.self, forKey: .max)
            let size = try container.decode(SizeInt.self, forKey: .size)
            
            let textureAtlas = try context.getOrLoadResource(at: path) as TextureAtlas

            self.init(atlas: textureAtlas, min: min, max: max, size: size)
        }
        
        public override func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if self.atlas.assetPath.isEmpty {
                throw AssetDecodingError.decodingProblem("Can't encode TextureAtlas.Slice, because TextureAtlas doesn't have resource path on disk.")
            }

            try container.encode(self.atlas.assetPath, forKey: .textureAtlasResource)
            try container.encode(self.min, forKey: .min)
            try container.encode(self.max, forKey: .max)
            try container.encode(SizeInt(width: self.width, height: self.height), forKey: .size)
        }
    }
}
