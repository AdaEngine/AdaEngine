//
//  TextAssetEncoder.swift
//  
//
//  Created by v.prusakov on 5/2/24.
//

import Yams

public final class TextAssetEncoder: AssetEncoder {

    public let assetMeta: AssetMeta
    let yamlEncoder: YAMLEncoder

    var encodedData: Data?

    init(meta: AssetMeta) {
        self.assetMeta = meta

        self.yamlEncoder = YAMLEncoder()
    }

    public func encode<T>(_ value: T) throws where T : Encodable {
        if let data = value as? Data {
            encodedData = data
        } else {
            let data = try yamlEncoder.encode(value).data(using: .utf8)
            encodedData = data
        }
    }
}
