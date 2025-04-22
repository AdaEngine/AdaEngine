//
//  TextAssetEncoder.swift
//  
//
//  Created by v.prusakov on 5/2/24.
//

import Yams

public final class TextAssetEncoder: AssetEncoder, @unchecked Sendable {

    public let assetMeta: AssetMeta
    let encoder: AnyEncoder

    private(set) var encodedData: Data?

    init(meta: AssetMeta) {
        self.assetMeta = meta
        self.encoder = YAMLEncoder()
    }

    public func encode<T>(_ value: T) throws where T : Encodable {
        if let data = value as? Data {
            self.encodedData = data
        } else {
            let data = try self.encoder.encode(value, userInfo: [
                .assetMetaInfo: self.assetMeta
            ])
            
            self.encodedData = data
        }
    }
}

protocol AnyEncoder: Sendable {
    func encode<T: Encodable>(_ value: T, userInfo: [CodingUserInfoKey: Any]) throws -> Data
}

extension YAMLEncoder: @unchecked @retroactive Sendable {}

extension YAMLEncoder: AnyEncoder {
    func encode<T>(_ value: T, userInfo: [CodingUserInfoKey : Any]) throws -> Data where T : Encodable {
        return try self.encode(value, userInfo: userInfo).data(using: .utf8)!
    }
}

extension JSONEncoder: AnyEncoder {
    func encode<T>(_ value: T, userInfo: [CodingUserInfoKey : Any]) throws -> Data where T : Encodable {
        self.userInfo = userInfo
        return try self.encode(value)
    }
}
