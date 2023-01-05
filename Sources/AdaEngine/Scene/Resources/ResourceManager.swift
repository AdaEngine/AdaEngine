//
//  File.swift
//  
//
//  Created by v.prusakov on 6/19/22.
//

import Foundation

public enum ResourceError: LocalizedError {
    case notExistAtPath(String)
    case message(String)
    
    public var errorDescription: String? {
        switch self {
        case .notExistAtPath(let path):
            return "Resource not exists at path: \(path)"
        case .message(let message):
            return message
        }
    }
}

/// Manager using for loading and saving resources in file system.
/// Each resource loaded from manager stored in memory cache.
/// If resource was loaded to memory, you recive reference to this resource.
public final class ResourceManager {
    
    private static var loadedResources: [String: Resource] = [:]
    
    ///
    /// ```swift
    /// let texture = try ResourceManager.load("armor.png") as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try ResourceManager.load("armor.png")
    /// ```
    /// - Parameter path: Path to the resource.
    /// - Returns: Instance of resource.
    public static func load<R: Resource>(
        _ path: String,
        from bundle: Bundle, // TODO: (Vlad) that temp solution, fix that later
        ignoreCache: Bool = false
    ) throws -> R {
        
        if let cachedResource = self.loadedResources[path], !ignoreCache {
            return cachedResource as! R
        }
        
        let uri = bundle.resourceURL!.appendingPathComponent(path)
        
        guard let data = FileManager.default.contents(atPath: uri.path) else {
            throw ResourceError.notExistAtPath(path)
        }
        
        let resource = try R.init(assetFrom: data)
        
        self.loadedResources[path] = resource
        
        return resource
    }
    
//    public static func save<R: Resource>(_ resource: R, at path: String) async throws {
//        let data = try resource.encodeContents()
//
//        let uri = self.fileSystemPath.appendingPathComponent(path)
//        try data.write(to: uri)
//    }
}
