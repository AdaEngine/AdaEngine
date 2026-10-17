import AdaAssets
import AdaNavigation
import Foundation

/// A validated .navmesh file loaded and saved through AssetsManager.
public struct NavigationMeshAsset: Asset {
    public let data: NavigationMeshData
    public var assetMetaInfo: AssetMetaInfo?

    public init(data: NavigationMeshData) {
        self.data = data
    }

    public init(from decoder: AssetDecoder) async throws {
        self.data = try NavigationMeshData(encoded: decoder.decode(Data.self))
    }

    public func encodeContents(with encoder: AssetEncoder) async throws {
        try encoder.encode(data.encoded())
    }

    public static func extensions() -> [String] { ["navmesh"] }
}
