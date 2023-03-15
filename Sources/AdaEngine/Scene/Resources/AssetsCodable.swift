//
//  AssetsCodable.swift
//  
//
//  Created by v.prusakov on 3/9/23.
//

import Yams

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

public protocol AssetEncoder {
    var assetMeta: AssetMeta { get }
    
    func encode<T: Encodable>(_ value: T) throws
}

public final class DefaultAssetEncoder: AssetEncoder {
    
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

// MARK: - Decoder -

public protocol AssetDecoder {
    var assetMeta: AssetMeta { get }
    
    func decode<T: Decodable>(_ type: T.Type) throws -> T
}

public extension CodingUserInfoKey {
    static var assetsDecodingContext: CodingUserInfoKey = CodingUserInfoKey(rawValue: "org.adaengine.assetdecoder.context")!
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

public final class DefaultAssetDecoder: AssetDecoder {
    
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
