//
//  AssetsManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/19/22.
//

import Foundation

public enum AssetError: LocalizedError {
    case notExistAtPath(String)
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .notExistAtPath(let path):
            return "Asset not exists at path: \(path)"
        case .message(let message):
            return message
        }
    }
}

// TODO: In the future, we should compile assets into binary

/// Manager using for loading and saving assets in file system.
/// Each asset loaded from manager stored in memory cache.
/// If asset was loaded to memory, you recive reference to this resource.
public final class AssetsManager {
    nonisolated(unsafe) private static var resourceDirectory: URL!

    private static let resKeyWord = "@res:"

    @AssetActor private static var loadedAssets: [Int: Asset] = [:]

    // MARK: - LOADING -

    /// Load a resource and saving it to memory cache. We use `@res:` prefix to link to resource folder.
    ///
    /// ```swift
    /// let texture = try await AssetsManager.load("@res:Assets/armor.png") as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try await AssetsManager.load("@res:Assets/armor.png")
    /// ```
    /// - Parameter path: Path to the resource.
    /// - Returns: Instance of resource.
    @AssetActor
    public static func load<A: Asset>(
        _ path: String,
        ignoreCache: Bool = false
    ) async throws -> A {
        let key = self.makeCacheKey(resource: A.self, path: path)

        if let cachedAsset = self.loadedAssets[key], !ignoreCache {
            return cachedAsset as! A
        }

        var processedPath = self.processPath(path)

        let hasFileExt = !processedPath.url.pathExtension.isEmpty

        if !hasFileExt {
            processedPath.url.appendPathExtension(A.assetType.fileExtenstion)
        }

        guard FileSystem.current.itemExists(at: processedPath.url) else {
            throw AssetError.notExistAtPath(processedPath.url.path)
        }

        let resource: A = try await self.load(from: processedPath, originalPath: path, bundle: nil)
        self.loadedAssets[key] = resource

        return resource
    }

    /// Load a resource with block current thread and saving it to memory cache.
    /// It may be useful to load resource without concurrent context.
    ///
    /// ```swift
    /// let texture = try AssetsManager.loadSync("Assets/armor.png") as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try AssetsManager.loadSync("Assets/armor.png")
    /// ```
    /// - Parameter path: Path to the resource.
    /// - Returns: Instance of resource.
    public static func loadSync<R: Asset>(
        _ path: String,
        ignoreCache: Bool = false
    ) throws -> R {
        let task = UnsafeTask<R> {
            return try await load(path)
        }

        return try task.get()
    }

    /// Load a resource and saving it to memory cache
    ///
    /// ```swift
    /// let texture = try await AssetsManager.load("Assets/armor.png", from: Bundle.module) as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try await AssetsManager.load("Assets/armor.png", from: Bundle.module)
    /// ```
    /// - Parameter path: Path to the resource.
    /// - Parameter bundle: Bundle where we search our resources
    /// - Returns: Instance of resource.
    @AssetActor
    public static func load<A: Asset>(
        _ path: String,
        from bundle: Bundle,
        ignoreCache: Bool = false
    ) async throws -> A {
        let key = self.makeCacheKey(resource: A.self, path: path)

        if let cachedAsset = self.loadedAssets[key], !ignoreCache {
            return cachedAsset as! A
        }

        let processedPath = self.processPath(path)
        guard let uri = bundle.url(forResource: processedPath.url.relativeString, withExtension: nil), FileSystem.current.itemExists(at: uri) else {
            throw AssetError.notExistAtPath(processedPath.url.relativeString)
        }

        let resource: A = try await self.load(
            from: Path(url: uri, query: processedPath.query),
            originalPath: path,
            bundle: bundle
        )
        self.loadedAssets[key] = resource

        return resource
    }
    
    /// Load a resource with block current thread and saving it to memory cache.
    /// It may be useful to load resource without concurrent context.
    ///
    /// ```swift
    /// let texture = try AssetsManager.loadSync("Assets/armor.png", from: Bundle.module) as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try AssetsManager.loadSync("Assets/armor.png", from: Bundle.module)
    /// ```
    /// - Parameter path: Path to the resource.
    /// - Parameter bundle: Bundle where we search our resources
    /// - Returns: Instance of resource.
    public static func loadSync<R: Asset>(
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
    public static func preload<R: Asset>(
        _ resourceType: R.Type,
        at path: String,
        completion: (@Sendable (Result<Void, Error>) -> Void)?
    ) {
        loadAsync(resourceType, at: path) { result in
            completion?(result.map({ _ in return }))
        }
    }

    /// Load resource in background and save it to the memory.
    public static func loadAsync<R: Asset>(
        _ resourceType: R.Type,
        at path: String,
        completion: @escaping @Sendable (Result<R, Error>) -> Void
    ) {
        Task(priority: .background) {
            do {
                let resource = try await self.load(path) as R
                completion(.success(resource))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - SAVING -

    // FIXME: Use binary format for specific resource types

    /// Save resource at path.
    @AssetActor
    public static func save<R: Asset>(
        _ resource: R,
        at path: String,
        name: String
    ) async throws {
        let fileSystem = FileSystem.current
        var processedPath = self.processPath(path)

        processedPath.url.append(path: name)
        
        if processedPath.url.pathExtension.isEmpty {
            processedPath.url.appendPathExtension(R.assetType.fileExtenstion)
        }

        let meta = AssetMeta(filePath: processedPath.url, queryParams: processedPath.query)
        let defaultEncoder = TextAssetEncoder(meta: meta)
        try await resource.encodeContents(with: defaultEncoder)

        let intermediateDirs = processedPath.url.deletingLastPathComponent()

        if !fileSystem.itemExists(at: intermediateDirs) {
            try fileSystem.createDirectory(at: intermediateDirs, withIntermediateDirectories: true)
        }

        if fileSystem.itemExists(at: processedPath.url) {
            try fileSystem.removeItem(at: processedPath.url)
        }

        guard let encodedData = defaultEncoder.encodedData else {
            throw AssetError.message("Can't get encoded data from resource.")
        }

        if !FileSystem.current.createFile(at: processedPath.url, contents: encodedData) {
            throw AssetError.message("Can't create file at path \(processedPath.url.absoluteString)")
        }
    }

    // MARK: - UNLOADING -

    /// Unload specific resource type from memory.
    @AssetActor
    public static func unload<R: Asset>(_ res: R.Type, at path: String) {
        let key = self.makeCacheKey(resource: res, path: path)
        self.loadedAssets[key] = nil
    }

    // MARK: - Public methods

    /// Set the root folder of all resources and remove all cached items.
    @AssetActor
    public static func setAssetDirectory(_ url: URL) throws {
        if url.hasDirectoryPath {
            throw AssetError.message("URL doesn't has directory path.")
        }

        if !FileSystem.current.itemExists(at: url) {
            try FileSystem.current.createDirectory(at: url, withIntermediateDirectories: true)
        }

        self.resourceDirectory = url
        
        self.loadedAssets.removeAll()
    }

    // MARK: - Internal

    // TODO: (Vlad) where we should call this method in embeddable view?
    static func initialize() throws {
        let fileSystem = FileSystem.current

        let resources = fileSystem.applicationFolderURL.appendingPathComponent("Assets")

        if !fileSystem.itemExists(at: resources) {
            try fileSystem.createDirectory(at: resources, withIntermediateDirectories: true)
        }

        self.resourceDirectory = resources
    }

    // MARK: - Private
    @AssetActor
    private static func load<A: Asset>(from path: Path, originalPath: String, bundle: Bundle?) async throws -> A {
        guard let data = FileSystem.current.readFile(at: path.url) else {
            throw AssetError.notExistAtPath(path.url.path)
        }

        let meta = AssetMeta(filePath: path.url, queryParams: path.query)
        let decoder = TextAssetDecoder(meta: meta, data: data)
        let resource = try await A.init(asset: decoder)
        
        resource.assetMetaInfo = AssetMetaInfo(
            assetPath: originalPath,
            assetName: path.url.lastPathComponent,
            bundlePath: bundle?.bundleIdentifier
        )

        return resource
    }
}

extension AssetsManager {
    struct Path {
        var url: URL
        let query: [AssetQuery]
    }

    static func getFilePath(from meta: AssetMetaInfo) -> Path {
       let processedPath = self.processPath(meta.assetPath)

       if let bundlePath = meta.bundlePath, let bundle = Bundle(path: bundlePath) {
           if let uri = bundle.url(forResource: processedPath.url.relativeString, withExtension: nil) {
               return Path(url: uri, query: processedPath.query)
           }
       }

       return processedPath
   }
}

private extension AssetsManager {


    // TODO: (Vlad) looks very unstable
    private static func makeCacheKey<R: Asset>(resource: R.Type, path: String) -> Int {
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

    /// Use Swift Coroutines but block current execution context and wait until task is done.
    private final class UnsafeTask<T>: @unchecked Sendable {

        private let semaphore = DispatchSemaphore(value: 0)
        private var result: Result<T, Error>?

        init(priority: TaskPriority = .userInitiated, block: @escaping @Sendable () async throws -> T) {
            Task.detached(priority: priority) { @Sendable [self, semaphore] in
                do {
                    self.result = .success(try await block())
                } catch {
                    self.result = .failure(error)
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

/// Actor for loading and saving resources.
@globalActor
public actor AssetActor {
    public static var shared = AssetActor()
}
