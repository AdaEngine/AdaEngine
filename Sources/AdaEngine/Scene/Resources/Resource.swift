//
//  Resource.swift
//  
//
//  Created by v.prusakov on 11/10/21.
//

import Foundation

/// The interface describe resource in a system.
/// Resource describe information needed to your game, like Audio, Mesh, Texture and etc.
/// You can create your own resource and use loaded it using `ResourceManager`.
///
/// Each resource should support saving and loading behaviour. In example we have simple scenario how to implement it,
/// but you can create custom `Codable` structure or use different path to do that.
///
/// ```swift
/// final class MyResource: Resource {
///
///     let text: String
///
///     static func load(from data: Data) throws -> MyResource {
///         let text = try JSONDecoder().decode(String.self, from: data)
///         return MyResource(text: text)
///     }
///
///     func encodeContents() throws -> Data {
///         return try JSONEncoder().encode(self.text)
///     }
/// }
/// ```
public protocol Resource: AnyObject {
    
    /// When resource load from the disk, this method will be called.
    /// Data is the same data given from `encodedContents()` method.
    /// - Parameter data: Resource data.
    /// - Returns: Return instance of resource
    init(asset decoder: AssetDecoder) throws
    
    /// To store resource on the disk, you should implement this method.
    /// This data will return to `load(from:)` method when Resource will load.
    /// - Returns: the resource data to be saved
    func encodeContents(with encoder: AssetEncoder) throws
    
    static var resourceType: ResourceType { get }
    
    var resourcePath: String { get set }
    var resourceName: String { get set }
}

public enum ResourceType: String {
    case texture = "atres"
    case mesh = "amsh"
    case material = "mat"
    case text = "res"
    case scene = "ascn"
    case audio = "audiores"
    
    case none
    
    public var fileExtenstion: String {
        return self.rawValue
    }
}

public struct AssetMeta {
    public let filePath: URL
    
    public var fileName: String { self.filePath.lastPathComponent }
}

public protocol AssetEncoder {
    var assetMeta: AssetMeta { get }
    
    func encode<T: Encodable>(_ value: T) throws
}

public enum AssetDecodingError: LocalizedError {
    case invalidAssetExtension(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAssetExtension(let string):
            return "[Asset Decoding Error] Invalid asset file extension \(string)"
        }
    }
}

public protocol AssetDecoder {
    var assetMeta: AssetMeta { get }
    
    func decode<T: Decodable>(_ type: T.Type) throws -> T
}

public class DefaultAssetDecoder: AssetDecoder {
    
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

import Yams

public class DefaultAssetEncoder: AssetEncoder {
    
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

public extension CodingUserInfoKey {
    static var assetsDecodingContext: CodingUserInfoKey = CodingUserInfoKey(rawValue: "org.adaengine.assetdecoder.context")!
}

public class AssetDecodingContext {
    
    private var resources: [String: WeakBox<AnyObject>] = [:]
    
    public func getResource<R: Resource>(at path: String) -> R? {
        self.resources[path]?.value as? R
    }
    
    public func appendResource<R: Resource>(_ resource: R) {
        self.resources[resource.resourcePath] = WeakBox(value: resource)
    }
}
