//
//  AssetsCodable.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/9/23.
//

// TODO: Mode for decoding/encoding files from/into binary format.

public struct AssetQuery: Sendable {
    public let name: String
    public let value: String?
}

public struct AssetMeta: Sendable {
    public let filePath: URL
    public let queryParams: [AssetQuery]
    
    public var fileName: String { self.filePath.lastPathComponent }
}

public enum AssetDecodingError: LocalizedError {
    case invalidAssetExtension(String)
    case decodingProblem(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAssetExtension(let string):
            return "[Asset Decoding Error] Invalid asset file extension \(string)"
        case .decodingProblem(let string):
            return "[Asset Decoding Error] Decoding finished with failure: \(string)"
        }
    }
}

// MARK: - Encoder -

/// A type that can encode itself to an external asset representation.
public protocol AssetEncoder: Sendable {

    /// - Returns: Meta information about asset.
    var assetMeta: AssetMeta { get }
    
    /// Use this method to encode content from asset.
    /// - Note: If you call this method more than once, than previous encode data will overwritten.
    func encode<T: Encodable>(_ value: T) throws
}

// MARK: - Decoder -

/// A type that can decode itself from external asset representation.
public protocol AssetDecoder: Sendable {

    /// - Returns: Meta information about asset.
    var assetMeta: AssetMeta { get }
    
    /// - Returns: asset file data.
    var assetData: Data { get }

    /// Use this method to decode content from asset.
    func decode<T: Decodable>(_ type: T.Type) throws -> T
}

// MARK: Asset Decoding Context

public extension CodingUserInfoKey {
    /// Returns ``AssetDecodingContext`` object that contains information about resources
    static let assetsDecodingContext: CodingUserInfoKey = CodingUserInfoKey(rawValue: "org.adaengine.assetdecoder.context")!
    
    /// Returns ``AssetEncodingContext`` object that contains information about resources
    static let assetsEncodingContext: CodingUserInfoKey = CodingUserInfoKey(rawValue: "org.adaengine.assetencoder.context")!

    /// Returns ``AssetMeta`` object that contains information about resources
    static let assetMetaInfo: CodingUserInfoKey = CodingUserInfoKey(rawValue: "org.adaengine.assetsMetaInfo")!
}

/// Context contains all resolved resources from decoding.
public final class AssetDecodingContext: @unchecked Sendable {

    private var resources: [String: WeakBox<AnyObject>] = [:]
    public let assetMeta: AssetMeta
    
    init(resources: [String : WeakBox<AnyObject>], assetMeta: AssetMeta) {
        self.resources = resources
        self.assetMeta = assetMeta
    }

    public func getOrLoadResource<A: Asset>(at path: String) throws -> A {
        if let value = self.resources[path]?.value as? A {
            return value
        } else {
            let value = try AssetsManager.loadSync(path) as A
            self.appendResource(value)
            
            return value
        }
    }

    public func appendResource<A: Asset>(_ resource: A) {
        self.resources[resource.assetPath] = WeakBox(value: resource)
    }
}

public extension Decoder {
    /// Returns instance of asset decoding context if exists.
    /// - Warning: Only available if you save asset from AssetsManager
    var assetsDecodingContext: AssetDecodingContext {
        guard let context = self.userInfo[.assetsDecodingContext] as? AssetDecodingContext else {
            fatalError("AssetDecodingContext info available if you save resouce from AssetsManager object.")
        }
        
        return context
    }
    
    /// Returns instance of asset meta
    /// - Warning: Only available if you save asset from AssetsManager
    var assetMeta: AssetMeta {
        guard let meta = self.userInfo[.assetMetaInfo] as? AssetMeta else {
            fatalError("AssetMeta info available if you save resouce from AssetsManager object.")
        }
        
        return meta
    }
}

public extension Encoder {
    
    /// Returns instance of asset meta
    /// /// - Warning: Only available if you load asset from AssetsManager
    var assetMeta: AssetMeta {
        guard let meta = self.userInfo[.assetMetaInfo] as? AssetMeta else {
            fatalError("AssetMeta info available if you load resouce from AssetsManager object.")
        }
        
        return meta
    }
    
    /// Returns instance of asset encoding context if exists.
    /// - Warning: Only available if you save asset from AssetsManager
    var assetsDecodingContext: AssetEncodingContext {
        guard let context = self.userInfo[.assetsEncodingContext] as? AssetEncodingContext else {
            fatalError("AssetEncodingContext info available if you save resouce from AssetsManager object.")
        }
        
        return context
    }
}

/// Context contains all resolved resources from encoding.
public final class AssetEncodingContext: @unchecked Sendable {
    public func saveSubresource<A: Asset>(_ asset: A) {

    }
}
