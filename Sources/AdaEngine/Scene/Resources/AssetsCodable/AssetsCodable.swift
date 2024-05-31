//
//  AssetsCodable.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/9/23.
//

// TODO: Mode for decoding/encoding files from/into binary format.

public struct AssetQuery {
    public let name: String
    public let value: String?
}

public struct AssetMeta {
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
public protocol AssetEncoder {

    var assetMeta: AssetMeta { get }
    
    func encode<T: Encodable>(_ value: T) throws
}

// MARK: - Decoder -

/// A type that can decode itself from external asset representation.
public protocol AssetDecoder {

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
    static var assetsDecodingContext: CodingUserInfoKey = CodingUserInfoKey(rawValue: "org.adaengine.assetdecoder.context")!
    
    /// Returns ``AssetMeta`` object that contains information about resources
    static var assetMetaInfo: CodingUserInfoKey = CodingUserInfoKey(rawValue: "org.adaengine.assetsMetaInfo")!
}

public final class AssetDecodingContext {

    private var resources: [String: WeakBox<AnyObject>] = [:]

    public func getResource<R: Resource>(at path: String) -> R? {
        self.resources[path]?.value as? R
    }

    public func appendResource<R: Resource>(_ resource: R) {
        self.resources[resource.resourcePath] = WeakBox(value: resource)
    }
}

public extension Decoder {
    /// Returns instance of asset decoding context if exists.
    var assetsDecodingContext: AssetDecodingContext? {
        return self.userInfo[.assetsDecodingContext] as? AssetDecodingContext
    }
    
    /// Returns instance of asset meta
    var assetMetaInfo: AssetMeta? {
        return self.userInfo[.assetMetaInfo] as? AssetMeta
    }
}

public extension Encoder {
    
    /// Returns instance of asset meta
    var assetMetaInfo: AssetMeta? {
        return self.userInfo[.assetMetaInfo] as? AssetMeta
    }
}
