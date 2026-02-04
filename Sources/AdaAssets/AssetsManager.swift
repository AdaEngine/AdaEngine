//
//  AssetsManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/19/22.
//

import AdaECS
import AdaUtils
import Dispatch
import Foundation
import Logging
import Tracing

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
// TODO: Remove unsafe and statics

/// Manager using for loading and saving assets in file system.
/// Each asset loaded from manager stored in memory cache.
/// If asset was loaded to memory, you recive reference to this resource.
public struct AssetsManager: Resource {

    private static let logger = Logger(label: "org.adaengine.AssetsManager")

    private nonisolated(unsafe) static var resourceDirectory: URL!

    private static let resKeyWord = "@res://"
    nonisolated(unsafe) private static var registredAssetTypes: [String: any Asset.Type] = [:]

    @AssetActor
    private static var storage: AssetsStorage = AssetsStorage()

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

    /// Load a resource. We use `@res://` prefix to link to assets folder.
    ///
    /// ```swift
    /// let texture = try await AssetsManager.load("@res://armor.png") as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try await AssetsManager.load("@res://armor.png")
    /// ```
    /// - Parameter path: Path to the resource.
    /// - Returns: Instance of resource.
    @AssetActor
    public static func load<A: Asset>(
        _ type: A.Type,
        at path: String,
        handleChanges: Bool = false
    ) async throws -> AssetHandle<A> {
        let span = AdaTrace.startSpan("Assets.load.\(String(reflecting: A.self))")
        defer {
            span.end()
        }
        if let cachedAsset = self.getHandlingResource(path: path, resourceType: A.self)?.value as? AssetHandle<A> {
            return cachedAsset
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
            self.storage.hotReloadingAssets[path, default: []].insert(
                HotReloadingAsset(
                    path: processedPath,
                    resource: A.self,
                    needsUpdate: false
                )
            )

            self.updateFileWatcher()
        }
        
        let resource: A = try await self.load(from: processedPath, originalPath: path, bundle: nil)
        let handle = AssetHandle(resource)
        self.storage.loadedAssets[path, default: []].insert(WeakBox(handle))

        return handle
    }
    
    /// Load a resource with block current thread and saving it to memory cache.
    /// It may be useful to load resource without concurrent context.
    ///
    /// ```swift
    /// let texture = try AssetsManager.loadSync("@res://armor.png") as Texture2D
    ///
    /// // == or ==
    ///
    /// let texture: Texture2D = try AssetsManager.loadSync("@res://armor.png")
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
        let span = AdaTrace.startSpan("Assets.load.\(String(reflecting: A.self))")
        defer {
            span.end()
        }
        if let cachedAsset = self.getHandlingResource(path: path, resourceType: A.self)?.value
            as? AssetHandle<A>
        {
            return cachedAsset
        }

        let processedPath = self.processPath(path)
        guard
            let uri = bundle.url(forResource: processedPath.url.relativeString, withExtension: nil),
            FileSystem.current.itemExists(at: uri)
        else {
            throw AssetError.notExistAtPath(processedPath.url.relativeString)
        }

        let resource: A = try await self.load(
            from: Path(url: uri, query: processedPath.query),
            originalPath: path,
            bundle: bundle
        )
        let handle = AssetHandle(resource)
        self.storage.loadedAssets[path, default: []].insert(WeakBox(handle))

        return handle
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
        try await AdaTrace.span("Assets.save.\(String(reflecting: R.self))") {
            let fileSystem = FileSystem.current
            var processedPath = self.processPath(path)

            processedPath.url.append(path: name)

            if processedPath.url.pathExtension.isEmpty {
                processedPath.url.appendPathExtension(R.extensions().first ?? "")
            }

            let meta = AssetMeta(filePath: processedPath.url, queryParams: processedPath.query)
            let defaultEncoder = TextAssetEncoder(meta: meta)
            try await asset.encodeContents(with: defaultEncoder)

            let intermediateDirs = processedPath.url.deletingLastPathComponent()

            if !fileSystem.itemExists(at: intermediateDirs) {
                try fileSystem.createDirectory(
                    at: intermediateDirs, withIntermediateDirectories: true)
            }

            if fileSystem.itemExists(at: processedPath.url) {
                try fileSystem.removeItem(at: processedPath.url)
            }

            guard let encodedData = defaultEncoder.encodedData else {
                throw AssetError.message("Can't get encoded data from resource.")
            }

            if !FileSystem.current.createFile(at: processedPath.url, contents: encodedData) {
                throw AssetError.message(
                    "Can't create file at path \(processedPath.url.absoluteString)")
            }
        }
    }

    // MARK: - UNLOADING -

    /// Unload specific resource type from memory.
    @AssetActor
    public static func unload<R: Asset>(_ res: R.Type, at path: String) {
        let loadedAssetIndex = self.storage.loadedAssets[path, default: []].firstIndex(where: {
            $0.value is AssetHandle<R>
        })
        if let loadedAssetIndex {
            self.storage.loadedAssets[path]?.remove(at: loadedAssetIndex)
        }
        self.storage.hotReloadingAssets[path] = nil
        self.updateFileWatcher()
    }

    // MARK: - Public methods

    public static func getAssetType(for typeName: String) -> (any Asset.Type)? {
        return unsafe registredAssetTypes[typeName]
    }

    public static func registerAssetType<T: Asset>(_ type: T.Type) {
        Task { @AssetActor in
            unsafe registredAssetTypes[String(reflecting: type)] = T.self
        }
    }

    /// Set the root folder of all resources and remove all cached items.
    @AssetActor
    public static func setAssetDirectory(_ url: URL) throws {
        if !FileSystem.current.itemExists(at: url) {
            try FileSystem.current.createDirectory(at: url, withIntermediateDirectories: true)
        }

        unsafe self.resourceDirectory = url
        self.storage.loadedAssets.removeAll()
    }

    // MARK: - Internal

    // TODO: (Vlad) where we should call this method in embeddable view?
    // TODO: (Vlad) We must set current dev path to the asset manager
    @_spi(AdaEngine)
    public static func initialize(filePath: StaticString) throws {
        let probablyNames = ["Assets", "Resources"]
        var projectDirectories: ProjectDirectories?
        for name in probablyNames {
            if let found = URL.findProjectDirectories(from: filePath, for: name) {
                projectDirectories = found
                break
            }
        }

        guard let projectDirectories else {
            throw AssetError.message("Missing package directory")
        }

        unsafe self.projectDirectories = projectDirectories

        #if DEBUG
            unsafe self.resourceDirectory = projectDirectories.assetsDirectory
        #else
            let fileSystem = FileSystem.current
            let resources = projectDirectories.assetsDirectory

            if !fileSystem.itemExists(at: resources) {
                try fileSystem.createDirectory(at: resources, withIntermediateDirectories: true)
            }

            unsafe self.resourceDirectory = resources
        #endif
    }

    @_spi(AdaEngine)
    @AssetActor
    public static func processResources() async throws {
        for (path, assets) in self.storage.hotReloadingAssets {
            for asset in assets where asset.needsUpdate {
                guard let loadedAssets = self.storage.loadedAssets[path] else {
                    logger.error("Resource \(asset.resource) is not found")
                    self.storage.hotReloadingAssets[path] = nil
                    continue
                }

                await process(loadedAssets: loadedAssets, at: path, asset: asset)
            }
        }
    }

    @AssetActor
    private static func process(
        loadedAssets: Set<WeakBox<AnyObject>>,
        at path: String,
        asset: AssetsManager.HotReloadingAsset
    ) async {
        for oldResources in loadedAssets {
            guard let oldResource = oldResources.value as? AnyAssetHandle else {
                continue
            }

            defer {
                var asset = asset
                asset.needsUpdate = false
                self.storage.hotReloadingAssets[path]?.insert(asset)
            }

            do {
                try await self.loadAndUpdateInternal(
                    assetType: asset.resource,
                    oldResource: oldResource,
                    from: asset.path,
                    originalPath: asset.path.url.path
                )
            } catch {
                logger.error(
                    "Error updating hot reloading asset \(asset.resource) at path \(asset.path.url.path): \(error)"
                )
            }
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
            logger.error("Error updating hot reloading assets: \(error)")
        }
    }

    @AssetActor
    private static func loadAndUpdateInternal(
        assetType: any Asset.Type,
        oldResource: any AnyAssetHandle,
        from path: Path,
        originalPath: String
    ) async throws {
        guard let data = FileSystem.current.readFile(at: path.url) else {
            throw AssetError.notExistAtPath(path.url.path)
        }
        let meta = AssetMeta(filePath: path.url, queryParams: path.query)
        let decoder = TextAssetDecoder(meta: meta, data: data)
        try await assetType.loadAndUpdateInternal(from: decoder, oldResource: oldResource)
    }

    @AssetActor
    private static func load<A: Asset>(from path: Path, originalPath: String, bundle: Bundle?)
        async throws -> A
    {
        guard let data = FileSystem.current.readFile(at: path.url) else {
            throw AssetError.notExistAtPath(path.url.path)
        }

        let meta = AssetMeta(filePath: path.url, queryParams: path.query)
        let decoder = TextAssetDecoder(meta: meta, data: data)
        var resource = try await A.init(from: decoder)

        resource.assetMetaInfo = AssetMetaInfo(
            assetId: RID(),
            assetPath: originalPath,
            assetName: path.url.lastPathComponent,
            bundlePath: bundle?.bundleIdentifier
        )

        return resource
    }
}

extension AssetsManager {
    struct Path: Sendable, Hashable {
        var url: URL
        let query: [AssetQuery]
    }

    static func getFilePath(from meta: AssetMetaInfo) -> Path {
        let processedPath = self.processPath(meta.assetPath)
        if let bundlePath = meta.bundlePath, let bundle = Bundle(path: bundlePath) {
            if let uri = bundle.url(
                forResource: processedPath.url.relativeString, withExtension: nil)
            {
                return Path(url: uri, query: processedPath.query)
            }
        }

        return processedPath
    }

    @AssetActor
    static func isAssetExistsInCache<A: Asset>(_ type: A.Type, at path: String) -> Bool {
        self.getHandlingResource(path: path, resourceType: type)?.value != nil
    }
}

extension AssetsManager {

    @AssetActor
    private static func getHandlingResource<A: Asset>(
        path: String,
        resourceType: A.Type
    ) -> WeakBox<AnyObject>? {
        self.storage.loadedAssets[path]?.first(where: { $0.value is AssetHandle<A> })
    }

    /// Replace tag `@res://` to relative path or create url from given path.
    private static func processPath(_ path: String) -> Path {
        var path = path
        var url: URL

        if path.hasPrefix(self.resKeyWord) && !path.hasPrefix("file://") {
            path.removeFirst(self.resKeyWord.count)
            url = unsafe self.resourceDirectory.appendingPathComponent(path)
        } else {
            url = path.hasPrefix("file://") ? URL(string: path)! : URL(fileURLWithPath: path)
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

        // Collect unique directory paths - on Windows, FileWatcher needs directories, not files
        var watchedDirectories = Set<String>()
        for (_, asset) in self.storage.hotReloadingAssets {
            guard let firstAsset = asset.first else {
                continue
            }
            // Get directory path - on Windows, FileWatcher needs directories, not files
            let directoryURL = firstAsset.path.url.deletingLastPathComponent()
                .resolvingSymlinksInPath()
            let directoryPath = directoryURL.path

            // Ensure directory exists before watching
            if FileSystem.current.itemExists(at: directoryURL) {
                watchedDirectories.insert(directoryPath)
            } else {
                logger.warning("Directory does not exist for watching: \(directoryPath)")
            }
        }

        guard !watchedDirectories.isEmpty else {
            logger.warning("No valid directories to watch")
            return
        }

        let watchedPaths = Array(watchedDirectories).compactMap {
            try? AbsolutePath(validating: $0)
        }
        guard !watchedPaths.isEmpty else {
            logger.warning("No valid absolute paths to watch")
            return
        }

        if self.fileWatcher?.paths == watchedPaths {
            return
        }

        self.fileWatcher = FileWatcher(
            paths: watchedPaths,
            latency: 0.1,
            block: { fsPaths in
                // Dispatch to AssetActor to avoid race conditions
                Task { @AssetActor in
                    for path in fsPaths {
                        // Resolve symlinks in incoming paths as well for consistent matching
                        let resolvedDirectoryPath = URL(fileURLWithPath: path.pathString)
                            .resolvingSymlinksInPath().path

                        // Find all assets in this directory and mark them for update
                        for (assetPath, assets) in self.storage.hotReloadingAssets {
                            guard let firstAsset = assets.first else {
                                continue
                            }
                            let assetDirectoryPath = firstAsset.path.url.deletingLastPathComponent()
                                .resolvingSymlinksInPath().path

                            // Check if this asset is in the changed directory
                            if assetDirectoryPath == resolvedDirectoryPath {
                                for var asset in assets {
                                    asset.needsUpdate = true
                                    self.storage.hotReloadingAssets[assetPath]?.insert(asset)
                                }
                                logger.info("Marked asset at path \(assetPath) for hot reload.")
                            }
                        }
                    }
                }
            }
        )

        do {
            if self.isHotReloadingEnabled {
                try self.fileWatcher?.start()
                logger.info("Started file watcher for paths: \(watchedPaths)")
            }
        } catch {
            logger.error("Error updating file watcher: \(error)")
        }
    }

    private static func fetchQuery(from string: String) -> [AssetQuery] {
        let quieries = string.split(separator: "&")
        return quieries.map { query in
            let pairs = query.split(separator: "=")
            if pairs.count == 2 {
                return AssetQuery(name: String(pairs[0]), value: String(pairs[1]))
            } else {
                return AssetQuery(name: String(pairs[0]), value: nil)
            }
        }
    }
}

extension AssetsManager {
    struct AssetsStorage: Sendable {
        var loadedAssets: [String: Set<WeakBox<AnyObject>>] = [:]
        var hotReloadingAssets: [String: Set<HotReloadingAsset>] = [:]
    }

    struct HotReloadingAsset: Sendable, Hashable {
        var path: Path
        var resource: any Asset.Type
        var needsUpdate: Bool = false

        static func == (lhs: AssetsManager.HotReloadingAsset, rhs: AssetsManager.HotReloadingAsset)
            -> Bool
        {
            lhs.path == rhs.path
                && ObjectIdentifier(lhs.resource) == ObjectIdentifier(rhs.resource)
                && lhs.needsUpdate == rhs.needsUpdate
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(self.path)
            hasher.combine(ObjectIdentifier(self.resource))
            hasher.combine(self.needsUpdate)
        }
    }
}

/// Actor for loading and saving resources.
@globalActor
public actor AssetActor {
    public static let shared = AssetActor()
}

extension Asset {
    @AssetActor
    fileprivate static func loadAndUpdateInternal(
        from asset: any AssetDecoder,
        oldResource: any AnyAssetHandle
    ) async throws {
        let resource = try await Self.init(from: asset)
        try oldResource.update(resource)
    }
}

extension URL {
    fileprivate static func findProjectDirectories(
        from file: StaticString,
        for name: String
    ) -> ProjectDirectories? {
        var currentURL = URL(filePath: file.description)
        var assetDirectory: URL?

        while currentURL.path != "/" {
            currentURL = currentURL.deletingLastPathComponent()
            let packageURL = currentURL.appending(path: "Package.swift")

            if FileManager.default.fileExists(atPath: packageURL.path) {
                return ProjectDirectories(
                    source: packageURL.deletingLastPathComponent(),
                    assetsDirectory: assetDirectory ?? currentURL.appending(path: name)
                )
            }

            let assetsDirectory = currentURL.appending(path: name)
            if FileManager.default.fileExists(atPath: assetsDirectory.path) {
                assetDirectory = assetsDirectory
            }
        }

        return nil
    }
}

struct ProjectDirectories {
    /// Source directory is a directory where we store all source code for the project.
    let source: URL

    /// Assets directory is a directory where we store all assets for the project.
    let assetsDirectory: URL
}
