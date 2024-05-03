//
//  TextAssetDecoder.swift
//
//
//  Created by v.prusakov on 5/2/24.
//

import Yams

public final class TextAssetDecoder: AssetDecoder {

    public let assetMeta: AssetMeta
    let yamlDecoder: YAMLDecoder
    let data: Data
    let context: AssetDecodingContext

    init(meta: AssetMeta, data: Data) {
        self.assetMeta = meta
        self.data = data

        self.context = AssetDecodingContext()

        self.yamlDecoder = YAMLDecoder(encoding: .utf16)
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if T.self == Data.self {
            return data as! T
        }

        return try yamlDecoder.decode(T.self, from: data, userInfo: [.assetsDecodingContext: self.context])
    }
}
