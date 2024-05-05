//
//  TileSource.swift
//
//
//  Created by v.prusakov on 5/5/24.
//

public class TileSource {

    struct TileData {
        var sizeInAtlas: Size = Size(width: 1, height: 1)
        var textureOffset: Vector2
        var modulateColor = Color(1.0, 1.0, 1.0, 1.0)
    }

    public typealias ID = RID

    func getTexture(at coordinates: PointInt) -> Texture2D {
        fatalErrorMethodNotImplemented()
    }
}

public class TileTextureAtlasSource: TileSource {

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

}
