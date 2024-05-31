//
//  TileTextureAtlasSource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/10/24.
//

import OrderedCollections

public class TileTextureAtlasSource: TileSource {

    // key - atlas coordinates
    private var tiles: OrderedDictionary<PointInt, AtlasTileData> = [:]

    private let textureAtlas: TextureAtlas

    public required init(from image: Image, size: Size, margin: Size = .zero) {
        self.textureAtlas = TextureAtlas(from: image, size: size, margin: margin)
        super.init()
    }

    public required init(atlas: TextureAtlas) {
        self.textureAtlas = atlas
        super.init()
    }
    
    // MARK: - Codable
    
    enum CodingKeys: CodingKey {
        case id, name, tiles, textureAtlas
    }
    
    struct TileCellData: Codable {
        let xy: PointInt
        let d: AtlasTileData
    }
    
    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.textureAtlas = try container.decode(TextureAtlas.self, forKey: .textureAtlas)
        
        super.init()
        
        self.name = try container.decode(String.self, forKey: .name)
        self.id = try container.decode(TileSource.ID.self, forKey: .id)
        try container.decode([TileCellData].self, forKey: .tiles).forEach { data in
            self.tiles[data.xy] = data.d
        }
    }
    
    public override func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.textureAtlas, forKey: .textureAtlas)
        
        let tiles = self.tiles.elements.map { (position, data) in
            TileCellData(xy: position, d: data)
        }
        
        try container.encode(tiles, forKey: .tiles)
    }
    
    // Tiles

    public func getTexture(at atlasCoordinates: PointInt) -> Texture2D {
        guard let tileData = self.tiles[atlasCoordinates] else {
            fatalError("Tile Not Found for coordinates \(atlasCoordinates)")
        }

        // Animated

        if tileData.animationFrameColumns > 1 {
            let animatedTexture = AnimatedTexture()
            animatedTexture.options = [.repeat]
            animatedTexture.framesCount = tileData.animationFrameColumns
            animatedTexture.framesPerSecond = Float(tileData.animationFrameColumns) / tileData.animationFrameDuration

            let alignment = tileData.animationColumnsAlignment

            for index in 0..<tileData.animationFrameColumns {
                let x = Float(atlasCoordinates.x + (alignment == .horizontal ? index : 0))
                let y = Float(atlasCoordinates.y + (alignment == .vertical ? index : 0))

                let slice = self.textureAtlas.textureSlice(at: [x, y])
                animatedTexture[index] = slice
            }

            return animatedTexture
        }

        return self.textureAtlas.textureSlice(at: Vector2(Float(atlasCoordinates.x), Float(atlasCoordinates.y)))
    }

    @discardableResult
    public func createTile(for atlasCoordinates: PointInt) -> AtlasTileData {
        let data = TileData()
        let atlasTileData = AtlasTileData(tileData: data)

        self.tiles[atlasCoordinates] = atlasTileData
        return atlasTileData
    }

    public func hasTile(at atlasCoordinates: PointInt) -> Bool {
        return self.tiles[atlasCoordinates] != nil
    }

    public func removeTile(at atlasCoordinates: PointInt) {
        self.tiles.removeValue(forKey: atlasCoordinates)

        self.setNeedsUpdate()
    }

    override func getTileData(at atlasCoordinates: PointInt) -> TileData {
        return tiles[atlasCoordinates]?.tileData ?? TileData()
    }

    // Animation
}

extension TileTextureAtlasSource {
    public class AtlasTileData: Codable {
        
        enum CodingKeys: String, CodingKey {
            case animationFrameDuration = "anim_dur"
            case animationFrameColumns = "anim_fr_clm"
            case animationColumnsAlignment = "anim_alig"
            case tileData = "d"
        }

        public enum Alignment: UInt8, Codable {
            case vertical
            case horizontal
        }

        public var animationFrameDuration: TimeInterval = 1.0
        public var animationFrameColumns: Int = 1
        public var animationColumnsAlignment: Alignment = .horizontal

        internal private(set) var tileData: TileData

        init(tileData: TileData) {
            self.tileData = tileData
        }

        @discardableResult
        public func setAnimationFrameDuration(_ duration: TimeInterval) -> Self {
            self.animationFrameDuration = duration
            return self
        }

        @discardableResult
        public func setAnimationFrameColumns(_ columns: Int) -> Self {
            self.animationFrameColumns = columns
            return self
        }

        @discardableResult
        public func setAnimationColumnsAlignment(_ alignment: Alignment) -> Self {
            self.animationColumnsAlignment = alignment
            return self
        }
    }
}
