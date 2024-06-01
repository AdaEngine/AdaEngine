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
/// final class MyResource: Resource {
///
///     let text: String
///
///     init(asset decoder: AssetDecoder) async throws {
///         let text = try decoder.decode(String.self, from: data)
///         self.text = text
///     }
///
///     func encodeContents(with encoder: AssetEncoder) async throws
///         return try encoder.encode(self.text)
///     }
/// }
/// ```
public protocol Resource: AnyObject {
    
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
    static var resourceType: ResourceType { get }

    /// If resource was initiated from resource, than property will return path to that file.
    var resourcePath: String { get set }

    /// If resource was initiated from resource, than property will return name of that file.
    var resourceName: String { get set }
}

extension Resource where Self: Codable {

    @ResourceActor public init(asset decoder: AssetDecoder) async throws {
        fatalErrorMethodNotImplemented()
//        self.init(from: decoder)
    }

    @ResourceActor public func encodeContents(with encoder: AssetEncoder) async throws {
        try encoder.encode(self)
    }
}

/// Contains resource type supported by AdaEngine.
public enum ResourceType: String {
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
