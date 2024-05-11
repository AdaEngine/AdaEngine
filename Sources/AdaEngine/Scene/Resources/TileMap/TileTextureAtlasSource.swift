//
//  TileTextureAtlasSource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/10/24.
//

public class TileTextureAtlasSource: TileSource {

    // key - atlas coordinates
    private var tiles: [PointInt: AtlasTileData] = [:]

    private let textureAtlas: TextureAtlas

    public init(from image: Image, size: Size, margin: Size = .zero) {
        self.textureAtlas = TextureAtlas(from: image, size: size, margin: margin)
    }

    public init(atlas: TextureAtlas) {
        self.textureAtlas = atlas
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
        var data = TileData()
        data.tileSet = self.tileSet
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
    public class AtlasTileData {

        public enum Alignment: UInt8 {
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
