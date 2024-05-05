//
//  TileSet.swift
//
//
//  Created by v.prusakov on 5/5/24.
//

public class TileSet: Resource {

    struct PhysicsLayer {
        var collisionLayer: CollisionGroup = .default
        var collisionMask: CollisionGroup = .default
    }

    public var tileSize: PointInt = [16, 16]

    private var physicsLayers: [PhysicsLayer] = []
    public private(set) var sources: [TileSource.ID: TileSource] = [:]

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

    public func addTileSource(_ source: TileSource) -> TileSource.ID {
        let identifier = RID()
        self.sources[identifier] = source

        return identifier
    }

    public func replaceTileSource(_ source: TileSource, at id: TileSource.ID) {
        self.sources[id] = source
    }

    public func removeTileSet(at id: TileSource.ID) {
        self.sources[id] = nil
    }

    // MARK: Physics
    
}
