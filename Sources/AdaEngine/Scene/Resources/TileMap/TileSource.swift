//
//  TileSource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

public class TileSource: Codable, @unchecked Sendable {

    static let invalidSource: Int = -1

    public internal(set) weak var tileSet: TileSet?

    public typealias ID = Int

    public internal(set) var id: ID = TileSource.invalidSource
    public var name: String = ""
    
    public init() { }
    
    // MARK: - Codable
    
    public required init(from decoder: any Decoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func encode(to encoder: any Encoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    // MARK: - Internal

    func getTileData(at atlasCoordinates: PointInt) -> TileData {
        fatalErrorMethodNotImplemented()
    }

    func setNeedsUpdate() {
        self.tileSet?.tileMap?.setNeedsUpdate()
    }
    
    // MARK: - Register
    
    nonisolated(unsafe) static private(set) var types: [String: TileSource.Type] = [:]
    
    /// Call this function if you inherited from TileSource
    public static func registerTileSource() {
        self.types[String(reflecting: self)] = Self.self
    }
}

struct TileData: Codable {
    
    enum CodingKeys: String, CodingKey {
        case modulateColor = "mColor"
        case flipH = "f_h"
        case flipV = "f_v"
    }
    
    var modulateColor = Color(1.0, 1.0, 1.0, 1.0)
    var flipH: Bool = false
    var flipV: Bool = false
}
