//
//  AssetsCodable.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/9/23.
//

import Foundation
import AdaUtils

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
    
    var encoder: (any Encoder)? { get }
    
    /// Use this method to encode content from asset.
    /// - Note: If you call this method more than once, than previous encode data will overwritten.
    func encode<T: Encodable>(_ value: T) throws
    
    func encode<A: Asset>(_ asset: A, to encoder: any Encoder) throws
}

// MARK: - Decoder -

/// A type that can decode itself from external asset representation.
public protocol AssetDecoder: Sendable {

    /// - Returns: Meta information about asset.
    var assetMeta: AssetMeta { get }
    
    /// - Returns: asset file data.
    var assetData: Data { get }
    
    /// - Returns: decoder.
    var decoder: (any Decoder)? { get }
    
    func getOrLoadResource<A: Asset>(
        _ resourceType: A.Type,
        at path: String
    ) throws -> AssetHandle<A>
    
    /// Use this method to decode content from asset.
    func decode<T: Decodable>(_ type: T.Type) throws -> T
    
    func decode<A: Asset>(_ type: A.Type, from decoder: any Decoder) throws -> A
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

public extension Decoder {
    /// Returns instance of asset decoding context if exists.
    /// - Warning: Only available if you save asset from AssetsManager
    var assetsDecoder: AssetDecoder {
        guard let context = self.userInfo[.assetsDecodingContext] as? AssetDecoder else {
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
    var assetsEncoder: AssetEncoder {
        guard let context = self.userInfo[.assetsEncodingContext] as? AssetEncoder else {
            fatalError("AssetEncodingContext info available if you save resouce from AssetsManager object.")
        }
        
        return context
    }
}
