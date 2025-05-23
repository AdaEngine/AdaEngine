//
//  Asset.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/10/21.
//

/// The interface describe asset in a system.
/// Asset describe information needed to your game, like Audio, Mesh, Texture and etc.
/// You can create your own asset and use loaded it using ``AssetsManager`` object.
///
/// Each asset should support saving and loading behaviour. In example we have simple scenario how to implement it,
/// but you can create custom ``Codable`` structure or use different path to do that.
///
/// ```swift
/// final class MapAsset: Asset {
///
///     let levelMap: [Int]
///
///     init(asset decoder: AssetDecoder) async throws {
///         let map = try decoder.decode([Int].self, from: data)
///         self.levelMap = map
///     }
///
///     func encodeContents(with encoder: AssetEncoder) async throws
///         return try encoder.encode(self.levelMap)
///     }
/// }
/// ```
///
/// Also, your asset can support ``Codable`` behaviour and for this scenario, you should implement only ``init(from decoder: Decoder)`` and ``func encode(to encoder: Encoder)`` methods.
/// Meta and other information will be available from userInfo. Use `Decoder.assetsDecodingContext`, `Decoder.assetMeta` and `Encoder.assetMeta` properties to get this info.
public protocol Asset: AnyObject, Sendable {
    
    /// When asset load from the disk, this method will be called.
    ///
    /// - Parameter data: Asset's data.
    /// - Returns: Return instance of asset
    init(asset decoder: AssetDecoder) async throws

    /// To store asset on the disk, you should implement this method.
    ///
    /// - Returns: the asset data to be saved
    func encodeContents(with encoder: AssetEncoder) async throws

    /// Type of asset.
    nonisolated static var assetType: AssetType { get }

    /// Return meta info
    var assetMetaInfo: AssetMetaInfo? { get set }
}

public extension Asset {
    /// If resource was initiated from resource, than property will return path to that file.
    /// /// - Warning: Do not override stored value.
    var assetPath: String {
        self.assetMetaInfo?.assetPath ?? ""
    }

    /// If asset was initiated from AssetsManager, than property will return name of that file.
    /// - Warning: Do not override stored value.
    var assetName: String {
        self.assetMetaInfo?.assetName ?? ""
    }
}

public struct AssetMetaInfo: Codable, Sendable {
    public let assetPath: String
    public let assetName: String
    public let bundlePath: String?
    
    public var fullFileURL: URL {
        return AssetsManager.getFilePath(from: self).url
    }
    
    enum CodingKeys: String, CodingKey {
        case assetPath = "assetPath"
        case bundlePath = "bundle"
    }
    
    init(assetPath: String, assetName: String, bundlePath: String?) {
        self.assetPath = assetPath
        self.assetName = assetName
        self.bundlePath = bundlePath
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.assetPath = try container.decode(String.self, forKey: .assetPath)
        self.bundlePath = try container.decodeIfPresent(String.self, forKey: .bundlePath)
        self.assetName = URL(string: assetPath)?.lastPathComponent ?? ""
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.assetPath, forKey: .assetPath)
        try container.encodeIfPresent(self.bundlePath, forKey: .bundlePath)
    }
}

/// Contains asset type supported by AdaEngine.
public enum AssetType: String, Sendable {
    case texture = "texres"
    case mesh = "mesh"
    case material = "mat"
    case text = "res"
    case scene = "ascn"
    case audio = "audiores"
    case font = "font"
    
    case none
    
    public var fileExtenstion: String {
        return self.rawValue
    }
}
