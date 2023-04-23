//
//  ResourceManager.swift
//  AdaEngine
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

// TODO: In the future, we should compile assets into binary
// TODO: Add documentation about query

/// Manager using for loading and saving resources in file system.
/// Each resource loaded from manager stored in memory cache.
/// If resource was loaded to memory, you recive reference to this resource.
public final class ResourceManager {
    
    private static var resourceDirectory: URL!
    
    private static let resKeyWord = "@res:"
    
    private static var loadedResources: [Int: Resource] = [:]
    
    // TODO: (Vlad) maybe latter we will use mutex lock instead GCD or Actor system
    private static var syncQueue = DispatchQueue(label: "queue.ResourceManager", qos: .userInitiated)
    private static var queue = DispatchQueue(label: "queue.ResourceManager.async", qos: .default)
    
    // MARK: - LOADING -
    
    /// Load a resource and saving it to memory cache. We use `@res:` prefix to link to resource folder.
    ///
    /// ```swift
    /// let texture = try ResourceManager.load("@res:Assets/armor.png") as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try ResourceManager.load("@res:Assets/armor.png")
    /// ```
    /// - Parameter path: Path to the resource.
    /// - Returns: Instance of resource.
    public static func load<R: Resource>(
        _ path: String
    ) throws -> R {
        try self.syncQueue.sync {
            
            let key = self.makeCacheKey(resource: R.self, path: path)
            
            if let cachedResource = self.loadedResources[key], cachedResource is R {
                return cachedResource as! R
            }
            
            var processedPath = self.processPath(path)
            
            let hasFileExt = !processedPath.url.pathExtension.isEmpty
            
            if !hasFileExt {
                processedPath.url.appendPathExtension(R.resourceType.fileExtenstion)
            }
            
            guard FileSystem.current.itemExists(at: processedPath.url) else {
                throw ResourceError.notExistAtPath(processedPath.url.path)
            }
            
            let resource: R = try self.load(from: processedPath)
            self.loadedResources[key] = resource
            
            return resource
        }
    }
    
    /// Load a resource and saving it to memory cache
    ///
    /// ```swift
    /// let texture = try ResourceManager.load("Assets/armor.png", from: Bundle.module) as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try ResourceManager.load("Assets/armor.png", from: Bundle.module)
    /// ```
    /// - Parameter path: Path to the resource.
    /// - Parameter bundle: Bundle where we search our resources
    /// - Returns: Instance of resource.
    public static func load<R: Resource>(
        _ path: String,
        from bundle: Bundle,
        ignoreCache: Bool = false
    ) throws -> R {
        try self.syncQueue.sync {
            
            let key = self.makeCacheKey(resource: R.self, path: path)
            
            if let cachedResource = self.loadedResources[key], !ignoreCache {
                return cachedResource as! R
            }
            
            let processedPath = self.processPath(path)
            guard let uri = bundle.url(forResource: processedPath.url.relativeString, withExtension: nil), FileSystem.current.itemExists(at: uri) else {
                throw ResourceError.notExistAtPath(processedPath.url.relativeString)
            }
            
            let resource: R = try self.load(from: Path(url: uri, query: processedPath.query))
            self.loadedResources[key] = resource
            
            return resource
        }
    }
    
    /// Pre load resource in background and save it to the memory.
    public static func preload<R: Resource>(
        _ resourceType: R.Type,
        at path: String,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        self.queue.async {
            do {
                _ = try self.load(path) as R
                completion?(.success(()))
            } catch {
                completion?(.failure(error))
            }
        }
    }
    
    /// Load resource in background ans save it to the memory.
    public static func loadAsync<R: Resource>(
        _ resourceType: R.Type,
        at path: String,
        completion: ((Result<R, Error>) -> Void)?
    ) {
        self.queue.async {
            do {
                let resource = try self.load(path) as R
                completion?(.success(resource))
            } catch {
                completion?(.failure(error))
            }
        }
    }
    
    // MARK: - SAVING -
    
    /// Save resource at path.
    public static func save<R: Resource>(
        _ resource: R,
        at path: String
    ) throws {
        try self.syncQueue.sync {
            let fileSystem = FileSystem.current
            var processedPath = self.processPath(path)
            
            if processedPath.url.pathExtension.isEmpty {
                processedPath.url.appendPathExtension(R.resourceType.fileExtenstion)
            }
            
            let meta = AssetMeta(filePath: processedPath.url, queryParams: processedPath.query)
            let defaultEncoder = DefaultAssetEncoder(meta: meta)
            try resource.encodeContents(with: defaultEncoder)
            
            let intermediateDirs = processedPath.url.deletingLastPathComponent()
            
            if !fileSystem.itemExists(at: intermediateDirs) {
                try fileSystem.createDirectory(at: intermediateDirs, withIntermediateDirectories: true)
            }
            
            if fileSystem.itemExists(at: processedPath.url) {
                try fileSystem.removeItem(at: processedPath.url)
            }
            
            guard let encodedData = defaultEncoder.encodedData else {
                throw ResourceError.message("Can't get encoded data from resource.")
            }
            
            if !FileSystem.current.createFile(at: processedPath.url, contents: encodedData) {
                throw ResourceError.message("Can't create file at path \(processedPath.url.absoluteString)")
            }
        }
    }
    
    // MARK: - UNLOADING -
    
    /// Unload specific resource type from memory.
    public static func unload<R: Resource>(_ res: R.Type, at path: String) {
        self.syncQueue.sync {
            let key = self.makeCacheKey(resource: res, path: path)
            self.loadedResources[key] = nil
        }
    }
    
    // MARK: - Public methods
    
    /// Set the root folder of all resources and remove all cached items.
    public static func setResourceDirectory(_ url: URL) throws {
        if url.hasDirectoryPath {
            throw ResourceError.message("URL doesn't has directory path.")
        }
        
        if !FileSystem.current.itemExists(at: url) {
            try FileSystem.current.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        self.resourceDirectory = url
        
        self.loadedResources.removeAll()
    }
    
    // MARK: - Internal
    
    // TODO: (Vlad) where we should call this method in embeddable view?
    static func initialize() throws {
        let fileSystem = FileSystem.current
        
        let resources = fileSystem.applicationFolderURL.appendingPathComponent("Resources")
        
        if !fileSystem.itemExists(at: resources) {
            try fileSystem.createDirectory(at: resources, withIntermediateDirectories: true)
        }
        
        self.resourceDirectory = resources
    }
    
    // MARK: - Private
    
    private static func load<R: Resource>(from path: Path) throws -> R {
        guard let data = FileSystem.current.readFile(at: path.url) else {
            throw ResourceError.notExistAtPath(path.url.path)
        }
        
        let meta = AssetMeta(filePath: path.url, queryParams: path.query)
        let decoder = DefaultAssetDecoder(meta: meta, data: data)
        let resource = try R.init(asset: decoder)
        resource.resourceName = path.url.lastPathComponent
        resource.resourcePath = path.url.path
        
        return resource
    }
    
    // TODO: (Vlad) looks very buggy
    private static func makeCacheKey<R: Resource>(resource: R.Type, path: String) -> Int {
        let cacheKey = path + "\(UInt(bitPattern: ObjectIdentifier(resource)))"
        return cacheKey.hashValue
    }
    
    /// Replace tag `@res:` to relative path or create url from given path.
    private static func processPath(_ path: String) -> Path {
        var path = path
        var url: URL
        
        if path.hasPrefix(self.resKeyWord) {
            path.removeFirst(self.resKeyWord.count)
            url = self.resourceDirectory.appendingPathComponent(path)
        } else {
            url = URL(fileURLWithPath: path)
        }
        
        let splitComponents = url.lastPathComponent.split(separator: "#")
        
        var query = [AssetQuery]()
        
        if !splitComponents.isEmpty {
            query = Self.fetchQuery(from: String(splitComponents.last!))
            
            url.deleteLastPathComponent()
            url.appendPathComponent(String(splitComponents.first!))
        }
        
        return Path(url: url, query: query)
    }
    
    private static func fetchQuery(from string: String) -> [AssetQuery] {
        let quieries = string.split(separator: "&")
        return quieries.map { query in
            let pairs = query.split(separator: "=")
            if (pairs.count == 2) {
                return AssetQuery(name: String(pairs[0]), value: String(pairs[1]))
            } else {
                return AssetQuery(name: String(pairs[0]), value: nil)
            }
        }
    }
    
    struct Path {
        var url: URL
        let query: [AssetQuery]
    }
}
