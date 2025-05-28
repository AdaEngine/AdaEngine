//
//  TextAssetDecoder.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/2/24.
//

import Foundation
import AdaUtils
import Yams

public final class TextAssetDecoder: AssetDecoder, @unchecked Sendable {
    private var resources: [String: WeakBox<AnyObject>] = [:]
    public let assetMeta: AssetMeta
    public let assetData: Data
    public let decoder: (any Decoder)?

    init(meta: AssetMeta, data: Data, decoder: (any Decoder)? = nil) {
        self.assetMeta = meta
        self.assetData = data
        self.decoder = decoder
    }
    
    public func decode<A: Asset>(_ type: A.Type, from decoder: any Decoder) throws -> A {
        let newDecoder = Self(
            meta: self.assetMeta,
            data: self.assetData,
            decoder: decoder
        )
        
        return try A.init(from: newDecoder)
    }
    
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
