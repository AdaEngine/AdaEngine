//
//  TextureAtlasTileSource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/10/24.
//

import AdaAssets
import AdaRender
import AdaUtils
import OrderedCollections
import Math

/// A tile source that uses a texture atlas.
public class TextureAtlasTileSource: TileSource, @unchecked Sendable {

    /// The tiles of the texture atlas tile source.
    private var tiles: OrderedDictionary<PointInt, AtlasTileData> = [:]

    /// The texture atlas of the texture atlas tile source.
    private let textureAtlas: TextureAtlas

    /// Initialize a new texture atlas tile source from an image.
    ///
    /// - Parameters:
    ///   - image: The image to initialize the texture atlas tile source from.
    ///   - size: The size of the texture atlas.
    ///   - margin: The margin of the texture atlas.
    public required init(from image: Image, size: SizeInt, margin: SizeInt = .zero) {
        self.textureAtlas = TextureAtlas(from: image, size: size, margin: margin)
        super.init()
    }

    /// Initialize a new texture atlas tile source from a texture atlas.
    ///
    /// - Parameter atlas: The texture atlas to initialize the texture atlas tile source from.
    public required init(atlas: TextureAtlas) {
        self.textureAtlas = atlas
        super.init()
    }
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case id, name, tiles, textureAtlas
    }
    
    struct TileCellData: Codable {
        
        enum CodingKeys: String, CodingKey {
            case position = "xy"
            case data = "ad"
        }
        
        let position: [Int]
        let data: AtlasTileData
    }
    
    /// Initialize a new texture atlas tile source from a decoder.
    ///
    /// - Parameter decoder: The decoder to initialize the texture atlas tile source from.
    /// - Throws: An error if the texture atlas tile source cannot be initialized from the decoder.
    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.textureAtlas = try container.decode(AssetHandle<TextureAtlas>.self, forKey: .textureAtlas).asset
        
        super.init()
        
        self.name = try container.decode(String.self, forKey: .name)
        self.id = try container.decode(TileSource.ID.self, forKey: .id)
        try container.decode([TileCellData].self, forKey: .tiles).forEach { data in
            self.tiles[PointInt(data.position)] = data.data
        }
    }
    
    /// Encode the texture atlas tile source to an encoder.
    ///
    /// - Parameter encoder: The encoder to encode the texture atlas tile source to.
    /// - Throws: An error if the texture atlas tile source cannot be encoded to the encoder.
    public override func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.id, forKey: .id)
        try container.encode(AssetHandle(self.textureAtlas), forKey: .textureAtlas)
        
        let tiles = self.tiles.elements.map { (position, data) in
            TileCellData(position: [position.x, position.y], data: data)
        }
        
        try container.encode(tiles, forKey: .tiles)
    }
    
    // Tiles

    /// Get the texture at the given atlas coordinates.
    ///
    /// - Parameter atlasCoordinates: The atlas coordinates to get the texture at.
    /// - Returns: The texture.
    public func getTexture(at atlasCoordinates: PointInt) -> Texture2D {
        guard let tileData = self.tiles[atlasCoordinates] else {
            fatalError("Tile Not Found for coordinates \(atlasCoordinates)")
        }
        if tileData.animationFrameColumns > 1 {
            let animatedTexture = AnimatedTexture()
            animatedTexture.options = [.repeat]
            animatedTexture.framesCount = tileData.animationFrameColumns
            animatedTexture.framesPerSecond = Float(tileData.animationFrameColumns) / tileData.animationFrameDuration

            let alignment = tileData.animationColumnsAlignment

            for index in 0..<tileData.animationFrameColumns {
                let x = atlasCoordinates.x + (alignment == .horizontal ? index : 0)
                let y = atlasCoordinates.y + (alignment == .vertical ? index : 0)

                let slice = self.textureAtlas.textureSlice(at: [x, y])
                animatedTexture[index] = slice
            }

            return animatedTexture
        }

        return self.textureAtlas.textureSlice(at: [atlasCoordinates.x, atlasCoordinates.y])
    }

    /// Create a tile for the texture atlas tile source.
    ///
    /// - Parameter atlasCoordinates: The atlas coordinates to create the tile for.
    /// - Returns: The created tile.
    @discardableResult
    public func createTile(for atlasCoordinates: PointInt) -> AtlasTileData {
        let data = TileData()
        let atlasTileData = AtlasTileData(tileData: data)

        self.tiles[atlasCoordinates] = atlasTileData
        return atlasTileData
    }

    /// Check if the texture atlas tile source has a tile at the given atlas coordinates.
    ///
    /// - Parameter atlasCoordinates: The atlas coordinates to check.
    /// - Returns: A Boolean value indicating whether the texture atlas tile source has a tile at the given atlas coordinates.
    public func hasTile(at atlasCoordinates: PointInt) -> Bool {
        return self.tiles[atlasCoordinates] != nil
    }

    /// Remove a tile from the texture atlas tile source.
    ///
    /// - Parameter atlasCoordinates: The atlas coordinates to remove the tile from.
    public func removeTile(at atlasCoordinates: PointInt) {
        self.tiles.removeValue(forKey: atlasCoordinates)

        self.setNeedsUpdate()
    }

    /// Get the tile data at the given atlas coordinates.
    ///
    /// - Parameter atlasCoordinates: The atlas coordinates to get the tile data at.
    /// - Returns: The tile data.
    override func getTileData(at atlasCoordinates: PointInt) -> TileData {
        return tiles[atlasCoordinates]?.tileData ?? TileData()
    }

    // Animation
}

extension TextureAtlasTileSource {
    /// A tile data for a texture atlas tile source.
    public class AtlasTileData: Codable {
        
        enum CodingKeys: String, CodingKey {
            case animationFrameDuration = "anim_dur"
            case animationFrameColumns = "anim_fr_clm"
            case animationColumnsAlignment = "anim_alig"
            case tileData = "td"
        }

        /// The alignment of the animation columns.
        public enum Alignment: UInt8, Codable {
            case vertical
            case horizontal
        }

        /// The duration of the animation frame.
        public var animationFrameDuration: TimeInterval = 1.0
        /// The number of the animation frame columns.
        public var animationFrameColumns: Int = 1
        /// The alignment of the animation columns.
        public var animationColumnsAlignment: Alignment = .horizontal

        /// The tile data of the atlas tile data.
        internal private(set) var tileData: TileData

        /// Initialize a new atlas tile data.
        ///
        /// - Parameter tileData: The tile data of the atlas tile data.
        init(tileData: TileData) {
            self.tileData = tileData
        }

        /// Set the animation frame duration.
        ///
        /// - Parameter duration: The duration of the animation frame.
        /// - Returns: The atlas tile data.
        @discardableResult
        public func setAnimationFrameDuration(_ duration: TimeInterval) -> Self {
            self.animationFrameDuration = duration
            return self
        }

        /// Set the animation frame columns.
        ///
        /// - Parameter columns: The number of the animation frame columns.
        /// - Returns: The atlas tile data.
        @discardableResult
        public func setAnimationFrameColumns(_ columns: Int) -> Self {
            self.animationFrameColumns = columns
            return self
        }

        /// Set the animation columns alignment.
        ///
        /// - Parameter alignment: The alignment of the animation columns.
        /// - Returns: The atlas tile data.
        @discardableResult
        public func setAnimationColumnsAlignment(_ alignment: Alignment) -> Self {
            self.animationColumnsAlignment = alignment
            return self
        }
    }
}
