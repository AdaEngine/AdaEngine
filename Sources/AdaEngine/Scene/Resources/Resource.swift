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
///     static func load(from data: Data) async throws -> MyResource {
///         let text = try JSONDecoder().decode(String.self, from: data)
///         return MyResource(text: text)
///     }
///
///     func encodeContents() async throws -> Data {
///         return try JSONEncoder().encode(self.text)
///     }
/// }
/// ```
public protocol Resource: AnyObject {
    
    /// When resource load from the disk, this method will be called.
    /// Data is the same data given from `encodedContents()` method.
    /// - Parameter data: Resource data.
    /// - Returns: Return instance of resource
    init(assetFrom data: Data) async throws
    
    /// To store resource on the disk, you should implement this method.
    /// This data will return to `load(from:)` method when Resource will load.
    /// - Returns: the resource data to be saved
    func encodeContents() async throws -> Data
}
