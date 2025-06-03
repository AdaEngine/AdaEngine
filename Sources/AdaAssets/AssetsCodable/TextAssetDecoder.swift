//
//  TextAssetDecoder.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/2/24.
//

import Foundation
import AdaUtils
import Yams

/// A decoder for assets that are stored in text format.
public final class TextAssetDecoder: AssetDecoder, @unchecked Sendable {
    /// The resources in the decoder.
    private var resources: [String: WeakBox<AnyObject>] = [:]
    /// The asset meta info of the decoder.
    public let assetMeta: AssetMeta
    /// The asset data of the decoder.
    public let assetData: Data
    /// The decoder of the decoder.
    public let decoder: (any Decoder)?

    /// Initialize a new text asset decoder.
    ///
    /// - Parameters:
    ///   - meta: The asset meta info of the decoder.
    ///   - data: The asset data of the decoder.
    init(meta: AssetMeta, data: Data, decoder: (any Decoder)? = nil) {
        self.assetMeta = meta
        self.assetData = data
        self.decoder = decoder
    }
    
    /// Decode an asset from a decoder.
    ///
    /// - Parameters:
    ///   - type: The type of the asset.
    ///   - decoder: The decoder to decode the asset from.
    /// - Returns: The decoded asset.
    public func decode<A: Asset>(_ type: A.Type, from decoder: any Decoder) throws -> A {
        let newDecoder = Self(
            meta: self.assetMeta,
            data: self.assetData,
            decoder: decoder
        )
        
        return try A.init(from: newDecoder)
    }
    
    /// Get or load a resource from the decoder.
    ///
    /// - Parameters:
    ///   - resourceType: The type of the resource.
    ///   - path: The path to the resource.
    /// - Returns: The resource.
    public func getOrLoadResource<A>(
        _ resourceType: A.Type,
        at path: String
    ) throws -> AssetHandle<A> where A : Asset {
        if let value = self.resources[path]?.value as? A {
            return AssetHandle(value)
        } else {
            let handle = try AssetsManager.loadSync(resourceType, at: path)
            self.appendResource(handle.asset)
            
            return handle
        }
    }
    
    /// Decode a decodable from the decoder.
    ///
    /// - Parameters:
    ///   - type: The type of the decodable.
    /// - Returns: The decoded decodable.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if let decoder {
            let container = try decoder.singleValueContainer()
            return try container.decode(T.self)
        }
        
        if T.self == Data.self {
            return self.assetData as! T
        }
        
        let decoder = YAMLDecoder(encoding: .utf8)
        return try decoder._decode(T.self, from: self.assetData, userInfo: [
            .assetsDecodingContext: self,
            .assetMetaInfo: self.assetMeta
        ])
    }
    
    /// Append a resource to the decoder.
    ///
    /// - Parameter resource: The resource to append.
    public func appendResource<A: Asset>(_ resource: A) {
        self.resources[resource.assetPath] = WeakBox(value: resource)
    }
}

protocol AnyDecoder {
    func _decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        userInfo: [CodingUserInfoKey: any Sendable]
    ) throws -> T
}

extension YAMLDecoder: AnyDecoder {
    func _decode<T>(
        _ type: T.Type,
        from data: Data,
        userInfo: [CodingUserInfoKey : any Sendable]
    ) throws -> T where T : Decodable {
        try self.decode(type, from: data, userInfo: userInfo)
    }
}

extension JSONDecoder: AnyDecoder {
    func _decode<T: Decodable>(_ type: T.Type, from data: Data, userInfo: [CodingUserInfoKey: any Sendable]) throws -> T {
        self.userInfo = userInfo
        return try self.decode(type, from: data)
    }
}
