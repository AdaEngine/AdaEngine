//
//  TileMap.swift
//  AdaEngine
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

    @Atomic public internal(set) var layers: [TileMapLayer] = [TileMapLayer()]

    public var resourcePath: String = ""
    public var resourceName: String = ""

    internal private(set) var needsUpdate: Bool = false

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
        layer.name = "Layer \(self.layers.count)"
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

    // MARK: - Internals

    // Update entire tilemap
    func setNeedsUpdate(updateLayers: Bool = false) {
        self.needsUpdate = true

        if updateLayers {
            self.layers.forEach { $0.setNeedsUpdate() }
        }
    }

    func updateDidFinish() {
        self.needsUpdate = false
    }

    // MARK: - Private

    private func tileSetDidChange() {
        self.setNeedsUpdate()

        self.tileSet.tileMap = self

        for layer in layers {
            layer.tileSet = self.tileSet
        }
    }
}
