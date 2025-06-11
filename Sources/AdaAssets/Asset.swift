//
//  Asset.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/10/21.
//

import Foundation

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
public protocol Asset: Sendable {
    
    /// When asset load from the disk, this method will be called.
    ///
    /// - Parameter data: Asset's data.
    /// - Returns: Return instance of asset
    init(from assetDecoder: AssetDecoder) throws

    /// To store asset on the disk, you should implement this method.
    ///
    /// - Returns: the asset data to be saved
    func encodeContents(with assetEncoder: AssetEncoder) throws

    /// Extensions for asset.
    static func extensions() -> [String]

    /// Return meta info
    var assetMetaInfo: AssetMetaInfo? { get set }
}

public extension Asset {
    /// If resource was initiated from resource, than property will return path to that file relative source dir.
    /// - Warning: Do not override stored value.
    var assetPath: String {
        self.assetMetaInfo?.assetPath ?? ""
    }

    /// If asset was initiated from AssetsManager, than property will return name of that file.
    /// - Warning: Do not override stored value.
    var assetName: String {
        self.assetMetaInfo?.assetName ?? ""
    }
    
    /// Return full path to Asset.
    var assetAbsolutePath: String {
        self.assetMetaInfo?.assetAbsolutePath.path() ?? ""
    }
}

/// A meta information about an asset.
///
/// This struct is used to store the meta information about an asset.
/// It is used to get the asset path, name and bundle path.
///
/// You can get the asset meta info using the ``Asset/assetMetaInfo`` property.
public struct AssetMetaInfo: Codable, Sendable {
    /// The path to the asset.
    public let assetPath: String
    /// The name of the asset.
    public let assetName: String
    /// The path to the bundle.
    public let bundlePath: String?
    
    /// The absolute path to the asset.
    public var assetAbsolutePath: URL {
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
    
    /// Initialize a new asset meta info from a decoder.
    ///
    /// - Parameter decoder: The decoder to initialize the asset meta info from.
    /// - Throws: An error if the asset meta info cannot be initialized from the decoder.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.assetPath = try container.decode(String.self, forKey: .assetPath)
        self.bundlePath = try container.decodeIfPresent(String.self, forKey: .bundlePath)
        self.assetName = URL(string: assetPath)?.lastPathComponent ?? ""
    }
    
    /// Encode the asset meta info to an encoder.
    ///
    /// - Parameter encoder: The encoder to encode the asset meta info to.
    /// - Throws: An error if the asset meta info cannot be encoded to the encoder.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.assetPath, forKey: .assetPath)
        try container.encodeIfPresent(self.bundlePath, forKey: .bundlePath)
    }
}

/// A handle to an asset.
///
/// The main reason to use AssetHandle is a hot reloading.
///
/// ```swift
/// let asset = try! AssetsManager.loadSync("@res://characters_packed.png", as: Image.self)
/// let assetHandle = AssetHandle(asset)
/// assetHandle.update(newAsset)
/// ```
///
public final class AssetHandle<T: Asset>: Codable, Sendable {
    /// The asset instance.
    public private(set) nonisolated(unsafe) var asset: T
    
    /// Initialize a new asset handle from an asset.
    /// - Parameter asset: The asset to initialize the asset handle from.
    /// - Warning: Only assets produced by ``AssetsManager`` can be used in hot reloading.
    public init(_ asset: T) {
        self.asset = asset
    }
    
    enum CodingKeys: CodingKey {
        case type
        case assetPath
        case meta
    }
    
    /// Initialize a new asset handle from a decoder.
    ///
    /// - Parameter decoder: The decoder to initialize the asset handle from.
    /// - Throws: An error if the asset handle cannot be initialized from the decoder.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let assetType = AssetsManager.getAssetType(for: type) ?? T.self
        let superDecoder = try container.superDecoder(forKey: .meta)
        let asset = try decoder.assetsDecoder.decode(assetType, from: superDecoder)
        self.asset = asset as! T
    }
    
    /// Encode the asset handle to an encoder.
    ///
    /// - Parameter encoder: The encoder to encode the asset handle to.
    /// - Throws: An error if the asset handle cannot be encoded to the encoder.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(reflecting: type(of: self.asset)), forKey: .type)
        if !asset.assetPath.isEmpty {
            try container.encode(asset.assetPath, forKey: .assetPath)
        }
        let superEncoder = container.superEncoder(forKey: .meta)
        try encoder.assetsEncoder.encode(asset, to: superEncoder)
    }

    func update(_ newAsset: T) async throws {
        self.asset = newAsset
    }
}

extension AssetHandle: AnyAssetHandle {
    @AssetActor
    func update(_ newAsset: any Asset) throws {
        guard newAsset is T else {
            throw AssetError.message("Asset \(newAsset) is not of type \(T.self)")
        }

        self.asset = newAsset as! T
    }
}

/// A protocol that represents an asset handle.
///
/// This protocol is used to update the asset handle.
protocol AnyAssetHandle {
    /// Update the asset handle with a new asset.
    ///
    /// - Parameter newAsset: The new asset to update the asset handle with.
    /// - Throws: An error if the asset handle cannot be updated with the new asset.
    @AssetActor
    func update(_ newAsset: any Asset) throws
}
