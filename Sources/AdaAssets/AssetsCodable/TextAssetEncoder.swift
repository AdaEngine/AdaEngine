//
//  TextAssetEncoder.swift
//  
//
//  Created by v.prusakov on 5/2/24.
//

import Foundation
import Yams

public final class TextAssetEncoder: AssetEncoder, @unchecked Sendable {

    public let assetMeta: AssetMeta
    public let encoder: (any Encoder)?

    private(set) var encodedData: Data?

    init(meta: AssetMeta, encoder: (any Encoder)? = nil) {
        self.assetMeta = meta
        self.encoder = encoder
    }

    public func encode<T>(_ value: T) throws where T : Encodable {
        if let encoder {
            var container = encoder.singleValueContainer()
            try container.encode(value)
            return
        }
        
        if let data = value as? Data {
            self.encodedData = data
        } else {
            let encoder = YAMLEncoder()
            encoder.options.floatingPointNumberFormatStrategy = .decimal
            let data = try encoder.encode(value, userInfo: [
                .assetMetaInfo: self.assetMeta,
                .assetsEncodingContext: self
            ])
            
            self.encodedData = data
        }
    }
    
    public func encode<A: Asset>(_ asset: A, to encoder: any Encoder) throws {
        let newEncoder = Self(meta: self.assetMeta, encoder: encoder)
        try asset.encodeContents(with: newEncoder)
    }
}

protocol AnyEncoder: Sendable {
    func encode<T: Encodable>(_ value: T, userInfo: [CodingUserInfoKey: any Sendable]) throws -> Data
}

extension YAMLEncoder: @unchecked @retroactive Sendable {}

extension YAMLEncoder: AnyEncoder {
    func encode<T>(_ value: T, userInfo: [CodingUserInfoKey : any Sendable]) throws -> Data where T : Encodable {
        return try self.encode(value, userInfo: userInfo).data(using: .utf8)!
    }
}

extension JSONEncoder: AnyEncoder {
    func encode<T>(_ value: T, userInfo: [CodingUserInfoKey : any Sendable]) throws -> Data where T : Encodable {
        self.userInfo = userInfo
        return try self.encode(value)
    }
}
