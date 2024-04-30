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

    @ResourceActor private static var loadedResources: [Int: Resource] = [:]

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
    @ResourceActor
    public static func load<R: Resource>(
        _ path: String
    ) async throws -> R {
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

        let resource: R = try await self.load(from: processedPath)
        self.loadedResources[key] = resource

        return resource
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
    @ResourceActor
    public static func load<R: Resource>(
        _ path: String,
        from bundle: Bundle,
        ignoreCache: Bool = false
    ) async throws -> R {
        let key = self.makeCacheKey(resource: R.self, path: path)

        if let cachedResource = self.loadedResources[key], !ignoreCache {
            return cachedResource as! R
        }

        let processedPath = self.processPath(path)
        guard let uri = bundle.url(forResource: processedPath.url.relativeString, withExtension: nil), FileSystem.current.itemExists(at: uri) else {
            throw ResourceError.notExistAtPath(processedPath.url.relativeString)
        }

        let resource: R = try await self.load(from: Path(url: uri, query: processedPath.query))
        self.loadedResources[key] = resource

        return resource
    }

    public static func loadSync<R: Resource>(
        _ path: String,
        from bundle: Bundle,
        ignoreCache: Bool = false
    ) throws -> R {
        let task = UnsafeTask<R> {
            return try await load(path, from: bundle, ignoreCache: ignoreCache)
        }

        return try task.get()
    }

    /// Pre load resource in background and save it to the memory.
    public static func preload<R: Resource>(
        _ resourceType: R.Type,
        at path: String,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        Task {
            do {
                _ = try await self.load(path) as R
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
        Task {
            do {
                let resource = try await self.load(path) as R
                completion?(.success(resource))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    // MARK: - SAVING -

    /// Save resource at path.
    @ResourceActor
    public static func save<R: Resource>(
        _ resource: R,
        at path: String
    ) async throws {
        let fileSystem = FileSystem.current
        var processedPath = self.processPath(path)

        if processedPath.url.pathExtension.isEmpty {
            processedPath.url.appendPathExtension(R.resourceType.fileExtenstion)
        }

        let meta = AssetMeta(filePath: processedPath.url, queryParams: processedPath.query)
        let defaultEncoder = DefaultAssetEncoder(meta: meta)
        try await resource.encodeContents(with: defaultEncoder)

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

    // MARK: - UNLOADING -

    /// Unload specific resource type from memory.
    @ResourceActor
    public static func unload<R: Resource>(_ res: R.Type, at path: String) {
        let key = self.makeCacheKey(resource: res, path: path)
        self.loadedResources[key] = nil
    }

    // MARK: - Public methods

    /// Set the root folder of all resources and remove all cached items.
    @ResourceActor
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
    @ResourceActor
    private static func load<R: Resource>(from path: Path) async throws -> R {
        guard let data = FileSystem.current.readFile(at: path.url) else {
            throw ResourceError.notExistAtPath(path.url.path)
        }

        let meta = AssetMeta(filePath: path.url, queryParams: path.query)
        let decoder = DefaultAssetDecoder(meta: meta, data: data)
        let resource = try await R.init(asset: decoder)
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

    private class UnsafeTask<T> {
        let semaphore = DispatchSemaphore(value: 0)
        private var result: Result<T, Error>?
        init(block: @escaping () async throws -> T) {
            Task {
                do {
                    result = .success(try await block())
                } catch {
                    result = .failure(error)
                }

                semaphore.signal()
            }
        }

        func get() throws -> T {
            if let result = result {
                return try result.get()
            }

            semaphore.wait()

            return try result!.get()
        }
    }
}

@globalActor
public actor ResourceActor {
    public static var shared = ResourceActor()
}
