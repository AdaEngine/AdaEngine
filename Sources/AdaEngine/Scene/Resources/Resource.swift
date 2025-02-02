//
//  Resource.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/10/21.
//

/// The interface describe asset resource in a system.
/// Resource describe information needed to your game, like Audio, Mesh, Texture and etc.
/// You can create your own resource and use loaded it using ``ResourceManager`` object.
///
/// Each resource should support saving and loading behaviour. In example we have simple scenario how to implement it,
/// but you can create custom ``Codable`` structure or use different path to do that.
///
/// ```swift
/// final class MapResource: Resource {
///
///     let levelMap: [Int]
///
///     init(asset decoder: AssetDecoder) async throws {
///         let map = try decoder.decode([Int].self, from: data)
///         self.levelMap = map
///     }
///
///     func encodeContents(with encoder: AssetEncoder) async throws
///         return try encoder.encode(self.levelMap)
///     }
/// }
/// ```
///
/// Also, your resource can support ``Codable`` behaviour and for this scenario, you should implement only ``init(from decoder: Decoder)`` and ``func encode(to encoder: Encoder)`` methods. 
/// Meta and other information will be available from userInfo. Use `Decoder.assetsDecodingContext`, `Decoder.assetMeta` and `Encoder.assetMeta` properties to get this info.
public protocol Resource: AnyObject, Sendable {
    
    /// When resource load from the disk, this method will be called.
    ///
    /// - Parameter data: Resource data.
    /// - Returns: Return instance of resource
    @ResourceActor init(asset decoder: AssetDecoder) async throws

    /// To store resource on the disk, you should implement this method.
    ///
    /// - Returns: the resource data to be saved
    @ResourceActor func encodeContents(with encoder: AssetEncoder) async throws

    /// Type of resource.
    @ResourceActor static var resourceType: ResourceType { get }

    /// Return meta info
    var resourceMetaInfo: ResourceMetaInfo? { get set }
}

public extension Resource {
    /// If resource was initiated from resource, than property will return path to that file.
    /// /// - Warning: Do not override stored value.
    var resourcePath: String {
        self.resourceMetaInfo?.resourcePath ?? ""
    }

    /// If resource was initiated from resource, than property will return name of that file.
    /// - Warning: Do not override stored value.
    var resourceName: String {
        self.resourceMetaInfo?.resourceName ?? ""
    }
}

public struct ResourceMetaInfo: Codable, Sendable {
    public let resourcePath: String
    public let resourceName: String
    public let bundlePath: String?
    
    public var fullFileURL: URL {
        return ResourceManager.getFilePath(from: self).url
    }
    
    enum CodingKeys: String, CodingKey {
        case resourcePath = "resPath"
        case bundlePath = "bundle"
    }
    
    init(resourcePath: String, resourceName: String, bundlePath: String?) {
        self.resourcePath = resourcePath
        self.resourceName = resourceName
        self.bundlePath = bundlePath
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.resourcePath = try container.decode(String.self, forKey: .resourcePath)
        self.bundlePath = try container.decodeIfPresent(String.self, forKey: .bundlePath)
        self.resourceName = URL(string: resourcePath)?.lastPathComponent ?? ""
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.resourcePath, forKey: .resourcePath)
        try container.encodeIfPresent(self.bundlePath, forKey: .bundlePath)
    }
}

/// Contains resource type supported by AdaEngine.
public enum ResourceType: String, Sendable {
    case texture = "texres"
    case mesh = "mesh"
    case material = "mat"
    case text = "res"
    case scene = "ascn"
    case audio = "audiores"
    case font = "font"
    
    case none
    
    public var fileExtenstion: String {
        return self.rawValue
    }
}
