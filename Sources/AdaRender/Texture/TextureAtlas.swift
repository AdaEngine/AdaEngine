//
//  TextureAtlas.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/30/22.
//

import AdaAssets
import Math
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
        let spriteSize: SizeInt
        let margin: SizeInt
        let info: AssetMetaInfo?
        let sampler: SamplerDescriptor
    }
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case margin
        case spriteSize
    }
    
    public required init(from assetDecoder: any AssetDecoder) async throws {
        let representation = try assetDecoder.decode(TextureAtlasAssetRepresentation.self)

        self.spriteSize = representation.spriteSize
        self.margin = representation.margin

        guard let filePath = representation.info?.assetAbsolutePath else {
            throw AssetDecodingError.decodingProblem("TextureAtlas: Can't decode TextureAtlas, because no file path passed.")
        }

        let image = try Image(contentsOf: filePath)
        super.init(image: image, samplerDescription: representation.sampler)
    }

    public override func encodeContents(with assetEncoder: any AssetEncoder) async throws {
        try assetEncoder.encode(
            TextureAtlasAssetRepresentation(
                spriteSize: self.spriteSize,
                margin: self.margin,
                info: self.assetMetaInfo,
                sampler: self.sampler.descriptor
            )
        )
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
        
        public let position: Vector2
        
        required init(atlas: TextureAtlas, min: Vector2, max: Vector2, size: SizeInt) {
            self.atlas = atlas
            self.max = max
            self.min = min
            self.position = [min.x * Float(atlas.width), min.y * Float(atlas.height)]
            
            super.init(gpuTexture: atlas.gpuTexture, sampler: atlas.sampler, size: size)
            self.assetMetaInfo = atlas.assetMetaInfo
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
        
        public convenience required init(from assetDecoder: any AssetDecoder) async throws {
            guard let container = try assetDecoder.decoder?.container(keyedBy: CodingKeys.self) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [],
                        debugDescription: "Failed to decode \(Self.self). Decoder not passed."
                    )
                )
            }
            let min = try container.decode(Vector2.self, forKey: .min)
            let max = try container.decode(Vector2.self, forKey: .max)
            let size = try container.decode(SizeInt.self, forKey: .size)
            let textureAtlasDecoder = try container.superDecoder(forKey: .textureAtlasResource)
            let textureAtlas = try await assetDecoder.decode(TextureAtlas.self, from: textureAtlasDecoder)
            self.init(atlas: textureAtlas, min: min, max: max, size: size)
        }
        
        public override func encodeContents(with encoder: any AssetEncoder) async throws {
            if self.atlas.assetPath.isEmpty {
                throw AssetDecodingError.decodingProblem("Can't encode TextureAtlas.Slice, because TextureAtlas doesn't have resource path on disk.")
            }
            
            guard var container = encoder.encoder?.container(keyedBy: CodingKeys.self) else {
                throw AssetDecodingError.decodingProblem("Can't encode TextureAtlas.Slice, because not encoder passed")
            }

            try await encoder.encode(self.atlas, to: container.superEncoder(forKey: .textureAtlasResource))
            try container.encode(self.min, forKey: .min)
            try container.encode(self.max, forKey: .max)
            try container.encode(SizeInt(width: self.width, height: self.height), forKey: .size)
        }
    }
}
