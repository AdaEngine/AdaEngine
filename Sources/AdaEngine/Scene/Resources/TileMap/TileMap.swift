//
//  TileMap.swift
//
//
//  Created by v.prusakov on 5/4/24.
//

public class TileMap: Resource {

    public static var resourceType: ResourceType = .text

    public var tileSet: TileSet = TileSet() {
        didSet {
            self.tileSetDidChange()
        }
    }

    public private(set) var layers: [TileMapLayer] = [TileMapLayer()]

    public var resourcePath: String = ""
    public var resourceName: String = ""

    public init() {
        self.tileSetDidChange()
    }

    public required init(asset decoder: AssetDecoder) async throws {
        fatalErrorMethodNotImplemented()
    }

    public func encodeContents(with encoder: AssetEncoder) async throws {
        fatalErrorMethodNotImplemented()
    }

    public func createLayer() -> TileMapLayer {
        let layer = TileMapLayer()
        self.layers.append(layer)
        return layer
    }

    public func removeLayer(_ layer: TileMapLayer) {
        guard let index = self.layers.firstIndex(where: { $0 === layer }) else {
            return
        }

        self.layers.remove(at: index)
    }

    public func setCell(for layerIndex: Int, coordinates: PointInt, sourceId: TileSource.ID, atlasCoordinates: PointInt) {
        if !layers.indices.contains(layerIndex) {
            return
        }

        let layer = self.layers[layerIndex]
        layer.setCell(at: coordinates, sourceId: sourceId, atlasCoordinates: atlasCoordinates)
    }

    public func removeCell(for layerIndex: Int, coordinates: PointInt) {
        if !layers.indices.contains(layerIndex) {
            return
        }

        let layer = self.layers[layerIndex]
        layer.removeCell(at: coordinates)
    }

    // MARK: - Private

    private func tileSetDidChange() {
        for layer in layers {
            layer.tileSet = self.tileSet
        }
    }
}

public final class TileMapLayer: Identifiable {

    public var name: String = ""

    public var id: RID = RID()

    public internal(set) weak var tileSet: TileSet?

    struct TileCellData {
        let coordinates: PointInt
        let sourceId: TileSource.ID
    }

    public var isEnabled: Bool = true

    internal private(set) var needUpdates = false

    var gridSize: Int = 16
    public var zIndex: Int = 0

    private(set) var tileMap: [PointInt: TileCellData] = [:]

    public func setCell(at position: PointInt, sourceId: TileSource.ID, atlasCoordinates: PointInt) {
        self.tileMap[position] = TileCellData(coordinates: atlasCoordinates, sourceId: sourceId)

        self.needUpdates = true
    }

    public func removeCell(at position: PointInt) {
        self.tileMap[position] = nil

        self.needUpdates = true
    }

    public func getSource(at position: PointInt) -> TileSource.ID {
        return self.tileMap[position]?.sourceId ?? .empty
    }

    // MARK: - Internals

    func updateDidFinish() {
        self.needUpdates = false
    }
}
