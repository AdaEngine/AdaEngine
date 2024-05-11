//
//  TextAssetDecoder.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/2/24.
//

import Yams

public final class TextAssetDecoder: AssetDecoder {

    public let assetMeta: AssetMeta
    public var assetData: Data

    let yamlDecoder: YAMLDecoder
    let context: AssetDecodingContext

    init(meta: AssetMeta, data: Data) {
        self.assetMeta = meta
        self.assetData = data

        self.context = AssetDecodingContext()

        self.yamlDecoder = YAMLDecoder(encoding: .utf16)
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if T.self == Data.self {
            return self.assetData as! T
        }

        return try self.yamlDecoder.decode(T.self, from: self.assetData, userInfo: [.assetsDecodingContext: self.context])
    }
}
