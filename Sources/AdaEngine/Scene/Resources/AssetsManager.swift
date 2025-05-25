//
//  AssetsManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/19/22.
//

import AdaUtils
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
    private static let resKeyWord = "@res://"
    nonisolated(unsafe) private static var registredAssetTypes: [String: any Asset.Type] = [:]
    
    @AssetActor
    private static var storage: AssetsStorage = AssetsStorage() {
        didSet {
            self.updateFileWatcher()
        }
    }
    
    @AssetActor
    private static var fileWatcher: FileWatcher?
    
    /// If hot reloading is enabled, the file watcher will be started.
    /// Default value is true.
    @AssetActor
    private static var isHotReloadingEnabled: Bool = true {
        didSet {
            self.updateHotReloadingAssets()
        }
    }
    
    nonisolated(unsafe) static var projectDirectories: ProjectDirectories!
    
    // MARK: - LOADING -
    
    /// Load a resource. We use `@res://` prefix to link to resource folder.
    ///
    /// ```swift
    /// let texture = try await AssetsManager.load("@res://Assets/armor.png") as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try await AssetsManager.load("@res://Assets/armor.png")
    /// ```
    /// - Parameter path: Path to the resource.
    /// - Returns: Instance of resource.
    @AssetActor
    public static func load<A: Asset>(
        _ type: A.Type,
        at path: String,
        handleChanges: Bool = false
    ) async throws -> AssetHandle<A> {
        let key = self.makeCacheKey(resource: A.self, path: path)
        if let cachedAsset = self.storage.loadedAssets[key]?.value as? A {
            return AssetHandle(cachedAsset)
        }
        
        let processedPath = self.processPath(path)
        let hasFileExt = !processedPath.url.pathExtension.isEmpty
        
        if !hasFileExt {
            throw AssetError.notExistAtPath(processedPath.url.path)
        }
        
        guard FileSystem.current.itemExists(at: processedPath.url) else {
            throw AssetError.notExistAtPath(processedPath.url.path)
        }
        
        if handleChanges {
            self.storage.hotReloadingAssets[path] = HotReloadingAsset(
                path: processedPath,
                key: key,
                resource: A.self,
                needsUpdate: false
            )
        }
        
        let resource: A = try await self.load(from: processedPath, originalPath: path, bundle: nil)
        self.storage.loadedAssets[key] = WeakBox(resource)
        
        return AssetHandle(resource)
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
        _ type: R.Type,
        at path: String
    ) throws -> AssetHandle<R> {
        let task = UnsafeTask<AssetHandle<R>> {
            return try await load(type, at: path)
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
        _ type: A.Type,
        at path: String,
        from bundle: Bundle,
        handleChanges: Bool = false
    ) async throws -> AssetHandle<A> {
        let key = self.makeCacheKey(resource: A.self, path: path)
        
        if let cachedAsset = self.storage.loadedAssets[key]?.value as? A {
            return AssetHandle(cachedAsset)
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
        self.storage.loadedAssets[key] = WeakBox(resource)
        
        return AssetHandle(resource)
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
        _ type: R.Type,
        at path: String,
        from bundle: Bundle
    ) throws -> AssetHandle<R> {
        let task = UnsafeTask<AssetHandle<R>> {
            return try await load(type, at: path, from: bundle)
        }
        
        return try task.get()
    }
    
    /// Load resource in background and save it to the memory.
    public static func loadAsync<R: Asset>(
        _ resourceType: R.Type,
        at path: String,
        completion: @escaping @Sendable (Result<AssetHandle<R>, Error>) -> Void
    ) {
        Task(priority: .background) {
            do {
                let resource = try await self.load(resourceType, at: path)
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
        _ asset: R,
        at path: String,
        name: String
    ) async throws {
        let fileSystem = FileSystem.current
        var processedPath = self.processPath(path)
        
        processedPath.url.append(path: name)
        
        if processedPath.url.pathExtension.isEmpty {
            processedPath.url.appendPathExtension(R.extensions().first ?? "")
        }
        
        let meta = AssetMeta(filePath: processedPath.url, queryParams: processedPath.query)
        let defaultEncoder = TextAssetEncoder(meta: meta)
        try asset.encodeContents(with: defaultEncoder)
        
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
        self.storage.loadedAssets[key] = nil
    }
    
    // MARK: - Public methods
    
    public static func getAssetType(for typeName: String) -> (any Asset.Type)? {
        return registredAssetTypes[typeName]
    }
    
    public static func registerAssetType<T: Asset>(_ type: T.Type) {
        Task { @AssetActor in
            registredAssetTypes[String(reflecting: type)] = T.self
        }
    }
    
    /// Set the root folder of all resources and remove all cached items.
    @AssetActor
    public static func setAssetDirectory(_ url: URL) throws {
        if !FileSystem.current.itemExists(at: url) {
            try FileSystem.current.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        self.resourceDirectory = url
        self.storage.loadedAssets.removeAll()
    }
    
    // MARK: - Internal
    
    // TODO: (Vlad) where we should call this method in embeddable view?
    // TODO: (Vlad) We must set current dev path to the asset manager
    static func initialize(filePath: StaticString) throws {
        let projectDirectories = try URL.findProjectDirectories(from: filePath)
        self.projectDirectories = projectDirectories
        
#if DEBUG
        self.resourceDirectory = projectDirectories.assetsDirectory
#else
        let fileSystem = FileSystem.current
        let resources = projectDirectories.assetsDirectory
        
        if !fileSystem.itemExists(at: resources) {
            try fileSystem.createDirectory(at: resources, withIntermediateDirectories: true)
        }
        
        self.resourceDirectory = resources
#endif
    }
    
    @AssetActor
    static func processResources() async throws {
        for (_, asset) in self.storage.hotReloadingAssets where asset.needsUpdate {
            guard let oldResource = self.storage.loadedAssets[asset.key]?.value as? any Asset else {
                print("Resource \(asset.resource) is not found")
                continue
            }
            
            try await self.loadAndUpdateInternal(
                assetType: asset.resource,
                oldResource: oldResource,
                from: asset.path,
                originalPath: asset.path.url.path
            )
        }
    }
    
    // MARK: - Private
    
    @AssetActor
    private static func updateHotReloadingAssets() {
        do {
            if self.isHotReloadingEnabled {
                try self.fileWatcher?.start()
            } else {
                self.fileWatcher?.stop()
            }
        } catch {
            print("Error updating hot reloading assets: \(error)")
        }
    }
    
    @AssetActor
    private static func loadAndUpdateInternal(
        assetType: any Asset.Type,
        oldResource: any Asset,
        from path: Path,
        originalPath: String
    ) async throws {
        // guard let data = FileSystem.current.readFile(at: path.url) else {
        //     throw AssetError.notExistAtPath(path.url.path)
        // }
        // let meta = AssetMeta(filePath: path.url, queryParams: path.query)
        // let decoder = TextAssetDecoder(meta: meta, data: data)
        // try await assetType.loadAndUpdateInternal(from: decoder, oldResource: oldResource)
    }
    
    @AssetActor
    private static func load<A: Asset>(from path: Path, originalPath: String, bundle: Bundle?) async throws -> A {
        guard let data = FileSystem.current.readFile(at: path.url) else {
            throw AssetError.notExistAtPath(path.url.path)
        }
        
        let meta = AssetMeta(filePath: path.url, queryParams: path.query)
        let decoder = TextAssetDecoder(meta: meta, data: data)
        let resource = try A.init(from: decoder)
        
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
    
    @AssetActor
    static func isAssetExistsInCache<A: Asset>(_ type: A.Type, at path: String) -> Bool {
        let key = makeCacheKey(resource: A.self, path: path)
        return self.storage.loadedAssets[key]?.value != nil
    }
}

private extension AssetsManager {
    // TODO: (Vlad) looks very unstable
    private static func makeCacheKey<R: Asset>(resource: R.Type, path: String) -> Int {
        let cacheKey = path + "\(UInt(bitPattern: ObjectIdentifier(resource)))"
        return cacheKey.hashValue
    }
    
    /// Replace tag `@res://` to relative path or create url from given path.
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
    
    @AssetActor
    private static func updateFileWatcher() {
        if self.storage.hotReloadingAssets.values.isEmpty {
            return
        }
        
        let paths = self.storage.hotReloadingAssets.values.map({ $0.path.url.path })
        
        if self.fileWatcher?.paths == paths {
            return
        }
        
        self.fileWatcher = FileWatcher(
            paths: paths,
            block: { paths in
                for path in paths {
                    var asset = self.storage.hotReloadingAssets[path]
                    asset?.needsUpdate = true
                    self.storage.hotReloadingAssets[path] = asset
                }
            }
        )
        
        do {
            if self.isHotReloadingEnabled {
                try self.fileWatcher?.start()
            }
        } catch {
            print("Error updating file watcher: \(error)")
        }
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

extension AssetsManager {
    struct AssetsStorage: Sendable {
        var loadedAssets: [Int: WeakBox<AnyObject>] = [:]
        var hotReloadingAssets: [String: HotReloadingAsset] = [:]
    }
    
    struct HotReloadingAsset: Sendable {
        var path: Path
        var key: Int
        var resource: any Asset.Type
        var needsUpdate: Bool = false
    }
}

/// Actor for loading and saving resources.
@globalActor
public actor AssetActor {
    public static var shared = AssetActor()
}

private extension Asset {
    static func loadAndUpdateInternal(
        from asset: any AssetDecoder,
        oldResource: any Asset
    ) async throws {
        let resource = try Self.init(from: asset)
        guard let oldResource = oldResource as? Self else {
            throw AssetError.message("Old resource is not of type \(Self.self)")
        }
        //        try await oldResource.update(resource)
    }
}

private extension URL {
    static func findProjectDirectories(from file: StaticString) throws -> ProjectDirectories {
        var currentURL = URL(filePath: file.description)
        var assetDirectory: URL?
        
        while currentURL.path != "/" {
            currentURL = currentURL.deletingLastPathComponent()
            let packageURL = currentURL.appending(path: "Package.swift")
            
            if FileManager.default.fileExists(atPath: packageURL.path) {
                return ProjectDirectories(
                    source: packageURL.deletingLastPathComponent(),
                    assetsDirectory: assetDirectory ?? currentURL.appending(path: "Assets")
                )
            }
            
            let assetsDirectory = currentURL.appending(path: "Assets")
            if FileManager.default.fileExists(atPath: assetsDirectory.path) {
                assetDirectory = assetsDirectory
            }
        }
        
        throw AssetError.message("Missing package directory")
    }
}

struct ProjectDirectories {
    /// Source directory is a directory where we store all source code for the project.
    let source: URL
    
    /// Assets directory is a directory where we store all assets for the project.
    let assetsDirectory: URL
}
