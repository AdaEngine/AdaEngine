//
//  TileSource.swift
//
//
//  Created by v.prusakov on 5/5/24.
//

public class TileSource {

    public internal(set) weak var tileSet: TileSet?

    public typealias ID = RID

    func getTexture(at coordinates: PointInt) -> Texture2D {
        fatalErrorMethodNotImplemented()
    }

    func getTileData(at coordinates: PointInt) -> TileData {
        fatalErrorMethodNotImplemented()
    }

    func setNeedsUpdate() {
        self.tileSet?.tileMap?.setNeedsUpdate()
    }
}

public class TileTextureAtlasSource: TileSource {

    private struct AtlasTileData {
        var animationFrameDuration: TimeInterval = 1.0
        var tileData: TileData
    }

    // key - atlas coordinates
    private var tiles: [PointInt: AtlasTileData] = [:]

    let textureAtlas: TextureAtlas

    public init(from image: Image, size: Size, margin: Size = .zero) {
        self.textureAtlas = TextureAtlas(from: image, size: size, margin: margin)
    }

    public init(atlas: TextureAtlas) {
        self.textureAtlas = atlas
    }

    override func getTexture(at coordinates: PointInt) -> Texture2D {
        textureAtlas.textureSlice(at: Vector2(Float(coordinates.x), Float(coordinates.y)))
    }

    // Tiles

    public func createTile(_ atlasCoordinates: PointInt) {
        var data = TileData()
        data.tileSet = self.tileSet
        let atlasTileData = AtlasTileData(tileData: data)

        self.tiles[atlasCoordinates] = atlasTileData
    }

    public func removeTile(_ atlasCoordinates: PointInt) {
        self.tiles.removeValue(forKey: atlasCoordinates)

        self.setNeedsUpdate()
    }

    override func getTileData(at coordinates: PointInt) -> TileData {
        return tiles[coordinates]?.tileData ?? TileData()
    }

    // Animation
}

struct TileData {

    weak var tileSet: TileSet?

    var modulateColor = Color(1.0, 1.0, 1.0, 1.0)
    var flipH: Bool = false
    var flipV: Bool = false
    var zIndex: Int = 0
}
