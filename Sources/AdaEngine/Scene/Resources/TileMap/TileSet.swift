//
//  TileSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import OrderedCollections

public class TileSet: Resource, Codable {

    struct PhysicsLayer {
        var collisionLayer: CollisionGroup = .default
        var collisionMask: CollisionGroup = .default
        var shape: Shape2DResource
    }

    public var tileSize: PointInt = [16, 16]

    private var physicsLayers: [PhysicsLayer] = []
    public private(set) var sources: OrderedDictionary<TileSource.ID, TileSource> = [:]

    public internal(set) weak var tileMap: TileMap?

    // MARK: - Resource

    public static var resourceType: ResourceType = .text

    public var resourcePath: String = ""
    public var resourceName: String = ""

    public init() {}

    public required init(asset decoder: AssetDecoder) async throws {
        let tileSet = try decoder.decode(TileSet.self)
        self.sources = tileSet.sources
        self.physicsLayers = tileSet.physicsLayers
        self.tileSize = tileSet.tileSize
    }

    public func encodeContents(with encoder: AssetEncoder) async throws {
        try encoder.encode(self)
    }
    
    // MARK: - Codable
    
    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.tileSize = try container.decode(PointInt.self, forKey: .tileSize)
        
        var sourcesContainer = try container.nestedUnkeyedContainer(forKey: .sources)
        while !sourcesContainer.isAtEnd {
            let sourceContainer = try sourcesContainer.nestedContainer(keyedBy: SourceCodingKeys.self)
            let sourceType = try sourceContainer.decode(String.self, forKey: .type)
            
            guard let value = TileSource.types[sourceType] else {
                return
            }
            
            let sourceDecoder = try sourceContainer.superDecoder(forKey: .data)
            let tileSource = try value.init(from: sourceDecoder)
            self.addTileSource(tileSource)
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.tileSize, forKey: .tileSize)
        
        var nestedContainer = container.nestedUnkeyedContainer(forKey: .sources)
        for source in sources.elements.values {
            var tileSource = nestedContainer.nestedContainer(keyedBy: SourceCodingKeys.self)
            try tileSource.encode(String(reflecting: source), forKey: .type)
            try tileSource.encode(source, forKey: .data)
        }
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

// MARK: - Codable & CodingKeys

extension TileSet {
    
    enum CodingKeys: String, CodingKey {
        case sources
        case tileSize
    }
    
    enum SourceCodingKeys: String, CodingKey {
        case type
        case data
    }
}
