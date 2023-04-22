//
//  Resource.swift
//  
//
//  Created by v.prusakov on 11/10/21.
//

/// The interface describe resource in a system.
/// Resource describe information needed to your game, like Audio, Mesh, Texture and etc.
/// You can create your own resource and use loaded it using ``ResourceManager``.
///
/// Each resource should support saving and loading behaviour. In example we have simple scenario how to implement it,
/// but you can create custom ``Codable`` structure or use different path to do that.
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
    
    /// Type of resource.
    static var resourceType: ResourceType { get }
    
    /// If resource was initiated from resource, than property will return path to that file.
    var resourcePath: String { get set }
    
    /// If resource was initiated from resource, than property will return name of that file.
    var resourceName: String { get set }
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
