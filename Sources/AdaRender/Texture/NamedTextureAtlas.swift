//
//  NamedTextureAtlas.swift
//  AdaEngine
//

import AdaAssets
import Foundation
import Math

/// Texture atlas keyed by string names (for packed UI assets). Distinct from grid-based ``TextureAtlas``.
public final class NamedTextureAtlas: Asset, @unchecked Sendable {

    public private(set) var texture: Texture2D

    public private(set) var entriesByKey: [String: AtlasRegion]

    public var assetMetaInfo: AssetMetaInfo?

    private var sliceCache: [String: Slice] = [:]

    public init(texture: Texture2D, entriesByKey: [String: AtlasRegion], assetMetaInfo: AssetMetaInfo? = nil) {
        self.texture = texture
        self.entriesByKey = entriesByKey
        self.assetMetaInfo = assetMetaInfo
    }

    public subscript(_ key: String) -> Texture2D? {
        slice(for: key)
    }

    public func slice(for key: String) -> Texture2D? {
        if let cached = sliceCache[key] {
            return cached
        }
        guard let region = entriesByKey[key] else {
            return nil
        }
        let piece = Slice(namedAtlas: self, region: region)
        sliceCache[key] = piece
        return piece
    }

    public func contains(_ key: String) -> Bool {
        entriesByKey[key] != nil
    }

    public var keys: [String] {
        entriesByKey.keys.sorted()
    }

    /// Builds a CPU ``Image`` for the logical sprite pixels (same dimensions as the original PNG).
    public func image(for key: String, atlasRGBA: Data, atlasWidth: Int, atlasHeight: Int) -> Image? {
        guard let region = entriesByKey[key] else {
            return nil
        }
        let w = region.originalSize.width
        let h = region.originalSize.height
        guard w > 0, h > 0 else {
            return nil
        }
        var out = Data(count: w * h * 4)
        let srcStride = atlasWidth * 4
        let ox = region.contentOriginInAtlas.x
        let oy = region.contentOriginInAtlas.y
        for row in 0 ..< h {
            let srcStart = (oy + row) * srcStride + ox * 4
            let dstStart = row * w * 4
            out.replaceSubrange(
                dstStart ..< dstStart + w * 4,
                with: atlasRGBA.subdata(in: srcStart ..< srcStart + w * 4)
            )
        }
        return Image(width: w, height: h, data: out, format: .rgba8)
    }

    public required init(from assetDecoder: any AssetDecoder) async throws {
        throw AssetDecodingError.decodingProblem("NamedTextureAtlas: asset file loading is not implemented.")
    }

    public func encodeContents(with assetEncoder: any AssetEncoder) async throws {
        throw AssetDecodingError.decodingProblem("NamedTextureAtlas: asset encoding is not implemented.")
    }

    public static func extensions() -> [String] {
        []
    }
}

// MARK: - Slice

public extension NamedTextureAtlas {

    /// A ``Texture2D`` view into one named region of the atlas.
    final class Slice: Texture2D, @unchecked Sendable {

        public private(set) var namedAtlas: NamedTextureAtlas

        private let uvMin: Vector2
        private let uvMax: Vector2

        public let position: Vector2

        init(namedAtlas: NamedTextureAtlas, region: AtlasRegion) {
            self.namedAtlas = namedAtlas
            self.uvMin = region.uvMin
            self.uvMax = region.uvMax
            self.position = [
                region.uvMin.x * Float(namedAtlas.texture.width),
                region.uvMin.y * Float(namedAtlas.texture.height)
            ]

            super.init(
                gpuTexture: namedAtlas.texture.gpuTexture,
                sampler: namedAtlas.texture.sampler,
                size: region.originalSize
            )
            self.assetMetaInfo = namedAtlas.texture.assetMetaInfo
            self.textureCoordinates = [
                [uvMin.x, uvMax.y],
                [uvMax.x, uvMax.y],
                [uvMax.x, uvMin.y],
                [uvMin.x, uvMin.y]
            ]
        }

        struct AssetError: LocalizedError {
            var errorDescription: String? {
                "Couldn't use named texture atlas slice as asset."
            }
        }

        enum CodingKeys: CodingKey {
            case namedAtlasResource
            case key
        }

        public convenience required init(from assetDecoder: any AssetDecoder) async throws {
            guard let container = try assetDecoder.decoder?.container(keyedBy: CodingKeys.self) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Failed to decode \(Self.self). Decoder not passed.")
                )
            }
            let key = try container.decode(String.self, forKey: .key)
            let atlasDecoder = try container.superDecoder(forKey: .namedAtlasResource)
            let namedAtlas = try await assetDecoder.decode(NamedTextureAtlas.self, from: atlasDecoder)
            guard let region = namedAtlas.entriesByKey[key] else {
                throw AssetDecodingError.decodingProblem("NamedTextureAtlas.Slice: missing key \(key).")
            }
            self.init(namedAtlas: namedAtlas, region: region)
        }

        public override func encodeContents(with encoder: any AssetEncoder) async throws {
            throw AssetDecodingError.decodingProblem("NamedTextureAtlas.Slice: encoding not supported.")
        }
    }
}
