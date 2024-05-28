//
//  TileSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

public class TileSet: Resource {

    struct PhysicsLayer {
        var collisionLayer: CollisionGroup = .default
        var collisionMask: CollisionGroup = .default
        var shape: Shape2DResource
    }

    public var tileSize: PointInt = [16, 16]

    private var physicsLayers: [PhysicsLayer] = []
    public private(set) var sources: [TileSource.ID: TileSource] = [:]

    public internal(set) weak var tileMap: TileMap?

    // MARK: - Resource

    public static var resourceType: ResourceType = .text

    public var resourcePath: String = ""
    public var resourceName: String = ""

    public init() {}

    public required init(asset decoder: AssetDecoder) async throws {
        fatalErrorMethodNotImplemented()
    }

    public func encodeContents(with encoder: AssetEncoder) async throws {
        fatalErrorMethodNotImplemented()
    }

    // MARK: - Public Methods

    // MARK: Tile Sources

    @discardableResult
    public func addTileSource(_ source: TileSource) -> TileSource.ID {
        let identifier = source.id != TileSource.invalidSource ? source.id : RID().id
        self.sources[identifier] = source
        source.tileSet = self

        return identifier
    }

    public func replaceTileSource(_ source: TileSource, at id: TileSource.ID) {
        self.sources[id] = source
    }

    public func removeTileSet(at id: TileSource.ID) {
        self.sources[id] = nil
    }
    
}
