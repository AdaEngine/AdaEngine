//
//  TextAssetDecoder.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/2/24.
//

import Yams

public final class TextAssetDecoder: AssetDecoder, @unchecked Sendable {
    public let assetMeta: AssetMeta
    public var assetData: Data

    let decoder: AnyDecoder
    let context: AssetDecodingContext

    init(meta: AssetMeta, data: Data) {
        self.assetMeta = meta
        self.assetData = data

        self.context = AssetDecodingContext()
        self.decoder = YAMLDecoder(encoding: .utf8)
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if T.self == Data.self {
            return self.assetData as! T
        }
        
        return try decoder._decode(T.self, from: self.assetData, userInfo: [
            .assetsDecodingContext: self.context,
            .assetMetaInfo: self.assetMeta
        ])
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
