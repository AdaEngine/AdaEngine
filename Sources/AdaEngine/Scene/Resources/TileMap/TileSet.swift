//
//  TileSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import OrderedCollections
import Math

public class TileSet: Asset, Codable, @unchecked Sendable {

    struct PhysicsLayer {
        var collisionLayer: CollisionGroup = .default
        var collisionMask: CollisionGroup = .default
        var shape: Shape2DResource
    }

    public var tileSize: PointInt = [16, 16]

    private var physicsLayers: [PhysicsLayer] = []
    public private(set) var sources: OrderedDictionary<TileSource.ID, TileSource> = [:]

    public internal(set) weak var tileMap: TileMap?
    
    // MARK: - Codable
    
    public required init(from decoder: any Decoder) throws {
        let file = try decoder.singleValueContainer().decode(FileContent.self)
        self.tileSize = file.tileSize
        
        for source in file.sources.elements.values {
            self.addTileSource(source)
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(FileContent(tileSize: self.tileSize, sources: self.sources))
    }

    // MARK: - Resource

    @MainActor
    public required init(asset decoder: AssetDecoder) async throws {
        let file = try decoder.decode(FileContent.self)
        self.tileSize = file.tileSize
        
        for source in file.sources.elements.values {
            self.addTileSource(source)
        }
    }
    
    public func encodeContents(with encoder: any AssetEncoder) throws {
        try encoder.encode(FileContent(tileSize: self.tileSize, sources: self.sources))
    }

    public static let assetType: AssetType = .text
    public nonisolated(unsafe) var assetMetaInfo: AssetMetaInfo?

    public init() {}

    // MARK: - Public Methods

    // MARK: Tile Sources
    
    private var currentTileSourceId: Int = -1
    
    private func getTileSourceNextId() -> Int {
        currentTileSourceId += 1
        return currentTileSourceId
    }

    @discardableResult
    public func addTileSource(_ source: TileSource) -> TileSource.ID {
        let identifier = source.id != TileSource.invalidSource ? source.id : getTileSourceNextId()
        source.id = identifier
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

// MARK: - FileContent & CodingKeys

extension TileSet {
    
    struct FileContent: Codable {
        
        let tileSize: PointInt
        private(set) var sources: OrderedDictionary<TileSource.ID, TileSource> = [:]
        
        init(tileSize: PointInt, sources: OrderedDictionary<TileSource.ID, TileSource>) {
            self.tileSize = tileSize
            self.sources = sources
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.tileSize = try container.decode(PointInt.self, forKey: .tileSize)
            
            var sourcesContainer = try container.nestedUnkeyedContainer(forKey: .sources)
            while !sourcesContainer.isAtEnd {
                let sourceContainer = try sourcesContainer.nestedContainer(keyedBy: SourceCodingKeys.self)
                let sourceType = try sourceContainer.decode(String.self, forKey: .type)
                
                guard let value = TileSource.types[sourceType] else {
                    continue
                }
                
                let sourceDecoder = try sourceContainer.superDecoder(forKey: .data)
                let tileSource = try value.init(from: sourceDecoder)
                sources[tileSource.id] = tileSource
            }
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.tileSize, forKey: .tileSize)
            
            var nestedContainer = container.nestedUnkeyedContainer(forKey: .sources)
            for source in sources.elements.values {
                var tileSource = nestedContainer.nestedContainer(keyedBy: SourceCodingKeys.self)
                try tileSource.encode(String(reflecting: type(of: source)), forKey: .type)
                try tileSource.encode(source, forKey: .data)
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case sources
        case tileSize
    }
    
    enum SourceCodingKeys: String, CodingKey {
        case type
        case data
    }
}
