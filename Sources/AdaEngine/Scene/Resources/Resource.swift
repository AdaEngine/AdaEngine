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
}

public enum ResourceType: UInt {
    case texture
    case mesh
    case material
    case text
    case scene
    case audio
    
    case none
}

public struct AssetMeta {
    public let filePath: URL
}

public protocol AssetEncoder {
    var assetMeta: AssetMeta { get }
    
    func encode<T: Encodable>(_ value: T) throws
}

public protocol AssetDecoder {
    var assetMeta: AssetMeta { get }
    
    func decode<T: Decodable>(_ type: T.Type) throws -> T
}

public class DefaultAssetDecoder: AssetDecoder {
    
    public let assetMeta: AssetMeta
    let yamlDecoder = YAMLDecoder()
    let data: Data
    
    init(meta: AssetMeta, data: Data) {
        self.assetMeta = meta
        self.data = data
    }
    
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if T.self == Data.self {
            return data as! T
        }
        
        return try yamlDecoder.decode(T.self, from: data)
    }
}

import Yams

public class DefaultAssetEncoder: AssetEncoder {
    
    public let assetMeta: AssetMeta
    let yamlEncoder = YAMLEncoder()
    
    var encodedData: Data?
    
    init(meta: AssetMeta) {
        self.assetMeta = meta
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
