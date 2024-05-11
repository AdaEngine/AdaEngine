//
//  TileSource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

public class TileSource {

    static let invalidSource: Int = Int.min

    public internal(set) weak var tileSet: TileSet?

    public typealias ID = Int

    public internal(set) var id: ID = TileSource.invalidSource
    public var name: String = ""

    func getTileData(at atlasCoordinates: PointInt) -> TileData {
        fatalErrorMethodNotImplemented()
    }

    func setNeedsUpdate() {
        self.tileSet?.tileMap?.setNeedsUpdate()
    }
}

struct TileData {

    weak var tileSet: TileSet?

    var modulateColor = Color(1.0, 1.0, 1.0, 1.0)
    var flipH: Bool = false
    var flipV: Bool = false
}
