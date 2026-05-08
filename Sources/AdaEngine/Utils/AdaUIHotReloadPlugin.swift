//
//  AdaUIHotReloadPlugin.swift
//  AdaEngine
//
//  Created by AdaEngine on 08.05.2026.
//

import AdaApp
import AdaAssets
import AdaUI
import AdaUtils
import Foundation
import Logging

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#endif

/// Plugin that loads AdaUI views from a hot-reload dylib and installs them into ``HotReloadView`` hosts.
///
/// The dylib must export a C symbol with this shape:
/// ```swift
/// @_cdecl("ada_ui_hot_reload_make_view")
/// public func adaUIHotReloadMakeView(_ id: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
///     switch String(cString: id) {
///     case "mobius.deck":
///         return AdaUIHotReloadPlugin.retainedOpaqueView(
///             UIContainerView(rootView: MobiusRootOverlay(startSlideID: .intro))
///         )
///     default:
///         return nil
///     }
/// }
/// ```
///
/// The returned pointer must be retained with ``retainedOpaqueView(_:)``. The plugin consumes that retain.
public struct AdaUIHotReloadPlugin: Plugin {
    public static let defaultEnvironmentKey = "ADAUI_HOT_RELOAD_DYLIB"
    public static let defaultBuildProductEnvironmentKey = "ADAUI_HOT_RELOAD_PRODUCT"
    public static let defaultBuildCommandEnvironmentKey = "ADAUI_HOT_RELOAD_BUILD_COMMAND"
    public static let defaultSymbolName = "ada_ui_hot_reload_make_view"

    private let storage: AdaUIHotReloadPluginStorage

    /// Creates a hot reload plugin.
    ///
    /// - Parameters:
    ///   - filePath: Source file used to discover the surrounding Swift package when `projectDirectory` is omitted.
    ///   - projectDirectory: Project directory to build and watch. Defaults to the current working directory.
    ///   - sourcePaths: Source paths to watch, relative to `projectDirectory` unless absolute.
    ///   - buildCommand: Build command to run from `projectDirectory`. If omitted, `ADAUI_HOT_RELOAD_BUILD_COMMAND`, then `swift build`, is used.
    ///   - buildProduct: Optional SwiftPM product to build. Defaults to `ADAUI_HOT_RELOAD_PRODUCT`.
    ///   - dylibName: Optional dynamic library filename/product hint used when discovering build artifacts.
    ///   - dylibPath: Manual dynamic library override. If omitted, the plugin builds and discovers the dylib.
    ///   - symbolName: Exported C symbol used to create views.
    ///   - watchPaths: Paths to watch. If omitted, `sourcePaths` are watched.
    ///   - reloadIDs: Specific hot-reload ids to reload when the dylib changes. Pass `nil` to reload all hosts.
    ///   - latency: File watcher debounce latency.
    public init(
        filePath: StaticString = #filePath,
        projectDirectory: String? = nil,
        sourcePaths: [String] = ["Sources"],
        buildCommand: String? = ProcessInfo.processInfo.environment[Self.defaultBuildCommandEnvironmentKey],
        buildProduct: String? = ProcessInfo.processInfo.environment[Self.defaultBuildProductEnvironmentKey],
        dylibName: String? = nil,
        dylibPath: String? = ProcessInfo.processInfo.environment[Self.defaultEnvironmentKey],
        symbolName: String = Self.defaultSymbolName,
        watchPaths: [String]? = nil,
        reloadIDs: [String]? = nil,
        latency: Double = 0.1
    ) {
        let discoveredProjectDirectory = try? AssetsManager
            .resolveProjectDirectories(filePath: filePath)
            .packageDirectory
            .path

        self.storage = AdaUIHotReloadPluginStorage(
            projectDirectory: projectDirectory ?? discoveredProjectDirectory ?? FileManager.default.currentDirectoryPath,
            sourcePaths: sourcePaths,
            buildCommand: buildCommand,
            buildProduct: buildProduct,
            dylibName: dylibName,
            dylibPath: dylibPath,
            symbolName: symbolName,
            watchPaths: watchPaths,
            reloadIDs: reloadIDs,
            latency: latency
        )
    }

    public func setup(in app: borrowing AppWorlds) {
        storage.setup()
    }

    public func destroy(for app: borrowing AppWorlds) {
        storage.destroy()
    }

    /// Converts a ``UIView`` into the retained opaque pointer expected from the hot-reload dylib symbol.
    public static func retainedOpaqueView(_ view: UIView) -> UnsafeMutableRawPointer {
        unsafe Unmanaged.passRetained(view).toOpaque()
    }
}

private final class AdaUIHotReloadPluginStorage: @unchecked Sendable {
    private let projectDirectory: String
    private let sourcePaths: [String]
    private let buildCommand: String?
    private let buildProduct: String?
    private let dylibName: String?
    private let dylibPath: String?
    private let symbolName: String
    private let explicitWatchPaths: [String]?
    private let reloadIDs: [String]?
    private let latency: Double
    private let logger = Logger(label: "org.adaengine.AdaUIHotReloadPlugin")

    private var library: AdaUIHotReloadDynamicLibrary?
    private var watcher: FileWatcher?
    private var sourceSnapshot: AdaUIHotReloadSourceSnapshot?
    private var isBuildRunning = false
    private var needsBuildAfterCurrent = false

    init(
        projectDirectory: String,
        sourcePaths: [String],
        buildCommand: String?,
        buildProduct: String?,
        dylibName: String?,
        dylibPath: String?,
        symbolName: String,
        watchPaths: [String]?,
        reloadIDs: [String]?,
        latency: Double
    ) {
        self.projectDirectory = projectDirectory
        self.sourcePaths = sourcePaths
        self.buildCommand = buildCommand
        self.buildProduct = buildProduct
        self.dylibName = dylibName
        self.dylibPath = dylibPath
        self.symbolName = symbolName
        self.explicitWatchPaths = watchPaths
        self.reloadIDs = reloadIDs
        self.latency = latency
    }

    @MainActor
    func setup() {
        let projectURL = URL(fileURLWithPath: projectDirectory, isDirectory: true)
            .resolvingSymlinksInPath()
        let library = AdaUIHotReloadDynamicLibrary(
            symbolName: symbolName,
            logger: logger
        )
        self.library = library

        UIHotReloadRuntime.setFactory { id in
            library.makeView(id: id)
        }

        sourceSnapshot = AdaUIHotReloadSourceSnapshot.capture(paths: watchPaths(projectURL: projectURL))
        startWatcher(projectURL: projectURL)

        if let dylibPath, !dylibPath.isEmpty {
            let sourceURL = URL(fileURLWithPath: dylibPath).resolvingSymlinksInPath()
            library.reload(from: sourceURL)
            reloadHosts()
        } else {
            scheduleBuildAndReload(projectURL: projectURL)
        }
    }

    @MainActor
    func destroy() {
        watcher?.stop()
        watcher = nil
        library = nil
        UIHotReloadRuntime.setFactory(nil)
    }

    @MainActor
    private func startWatcher(projectURL: URL) {
        let paths = watchPaths(projectURL: projectURL)
        guard !paths.isEmpty else {
            logger.warning("AdaUI hot reload did not start a watcher because no valid watch paths were found.")
            return
        }

        watcher = FileWatcher(paths: paths, latency: latency) { [weak self] changedPaths in
            Task { @MainActor [weak self] in
                self?.logger.info("AdaUI hot reload file event: \(changedPaths.map(\.pathString).joined(separator: ", "))")
                guard let self else {
                    return
                }

                if let dylibPath = self.dylibPath, !dylibPath.isEmpty {
                    guard self.consumeSaveEvent(projectURL: projectURL) else {
                        return
                    }

                    self.library?.reload(from: URL(fileURLWithPath: dylibPath).resolvingSymlinksInPath())
                    self.reloadHosts()
                } else {
                    guard self.consumeSaveEvent(projectURL: projectURL) else {
                        return
                    }

                    self.scheduleBuildAndReload(projectURL: projectURL)
                }
            }
        }

        do {
            try watcher?.start()
            logger.info("Started AdaUI hot reload watcher for \(paths.map(\.pathString).joined(separator: ", "))")
        } catch {
            logger.error("Failed to start AdaUI hot reload watcher: \(error)")
            watcher = nil
        }
    }

    @MainActor
    private func watchPaths(projectURL: URL) -> [AbsolutePath] {
        let rawPaths = explicitWatchPaths ?? sourcePaths

        return rawPaths.compactMap { path in
            let url = URL(fileURLWithPath: path, relativeTo: projectURL).standardizedFileURL
            do {
                return try AbsolutePath(validating: url.path)
            } catch {
                logger.warning("Ignoring invalid AdaUI hot reload watch path \(path): \(error)")
                return nil
            }
        }
    }

    @MainActor
    private func consumeSaveEvent(projectURL: URL) -> Bool {
        let nextSnapshot = AdaUIHotReloadSourceSnapshot.capture(paths: watchPaths(projectURL: projectURL))
        defer {
            sourceSnapshot = nextSnapshot
        }

        guard let sourceSnapshot else {
            return true
        }

        let didSave = sourceSnapshot != nextSnapshot
        if !didSave {
            logger.debug("Ignoring AdaUI hot reload file event because watched file save state did not change.")
        }

        return didSave
    }

    @MainActor
    private func scheduleBuildAndReload(projectURL: URL) {
        if isBuildRunning {
            needsBuildAfterCurrent = true
            return
        }

        isBuildRunning = true
        let runner = AdaUIHotReloadBuildRunner(
            projectURL: projectURL,
            sourcePaths: sourcePaths,
            buildCommand: buildCommand,
            buildProduct: buildProduct,
            dylibName: dylibName ?? buildProduct
        )

        Task {
            let result = await runner.build()
            await MainActor.run {
                self.isBuildRunning = false

                switch result {
                case .success(let dylibURL):
                    self.library?.reload(from: dylibURL)
                    self.reloadHosts()
                case .failure(let error):
                    self.logger.error("\(error)")
                }

                if self.needsBuildAfterCurrent {
                    self.needsBuildAfterCurrent = false
                    self.scheduleBuildAndReload(projectURL: projectURL)
                }
            }
        }
    }

    @MainActor
    private func reloadHosts() {
        if let reloadIDs {
            for id in reloadIDs {
                UIHotReloadRuntime.reload(id: id)
            }
        } else {
            UIHotReloadRuntime.reloadAll()
        }
    }
}

private struct AdaUIHotReloadSourceSnapshot: Equatable {
    private struct FileState: Equatable {
        var size: Int
        var modificationDate: Date
    }

    private var files: [String: FileState]

    static func capture(paths: [AbsolutePath]) -> Self {
        var files: [String: FileState] = [:]

        for path in paths {
            let url = URL(fileURLWithPath: path.pathString).standardizedFileURL
            collectFiles(at: url, into: &files)
        }

        return Self(files: files)
    }

    private static func collectFiles(
        at url: URL,
        into files: inout [String: FileState]
    ) {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey]) else {
            return
        }

        if values.isDirectory == true {
            collectDirectoryFiles(at: url, into: &files)
        } else if values.isRegularFile == true {
            collectFile(at: url, into: &files)
        }
    }

    private static func collectDirectoryFiles(
        at directoryURL: URL,
        into files: inout [String: FileState]
    ) {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            collectFile(at: url, into: &files)
        }
    }

    private static func collectFile(
        at url: URL,
        into files: inout [String: FileState]
    ) {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true,
              let modificationDate = values.contentModificationDate else {
            return
        }

        files[url.standardizedFileURL.path] = FileState(
            size: values.fileSize ?? 0,
            modificationDate: modificationDate
        )
    }
}

private struct AdaUIHotReloadBuildRunner: Sendable {
    let projectURL: URL
    let sourcePaths: [String]
    let buildCommand: String?
    let buildProduct: String?
    let dylibName: String?

    func build() async -> Result<URL, AdaUIHotReloadBuildError> {
        do {
            let command = resolvedBuildCommand()
            let output = try run(command: command)
            guard let dylibURL = discoverDylib(in: output) else {
                return .failure(.dynamicLibraryNotFound(command: command, output: output))
            }

            return .success(try relinkHotReloadDylibIfPossible(dylibURL))
        } catch let error as AdaUIHotReloadBuildError {
            return .failure(error)
        } catch {
            return .failure(.buildFailed(command: resolvedBuildCommand(), exitCode: nil, output: "\(error)"))
        }
    }

    private func resolvedBuildCommand() -> String {
        if let buildCommand, !buildCommand.isEmpty {
            return buildCommand
        }

        var command = "swift build --disable-build-manifest-caching"
        if let buildProduct, !buildProduct.isEmpty {
            command += " --product \(Self.shellEscaped(buildProduct))"
        }
        return command
    }

    private func run(command: String) throws -> String {
        let process = Process()
        process.currentDirectoryURL = projectURL

        #if os(Windows)
        process.executableURL = URL(fileURLWithPath: "cmd.exe")
        process.arguments = ["/C", command]
        #else
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-lc", command]
        #endif

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw AdaUIHotReloadBuildError.buildFailed(
                command: command,
                exitCode: process.terminationStatus,
                output: output
            )
        }

        return output
    }

    private func discoverDylib(in output: String) -> URL? {
        let outputCandidate = output
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`:;,()[]{}")) }
            .compactMap(candidateURL(from:))
            .filter { !isDebugSymbolsArtifact($0) }
            .filter { !isHotReloadRelinkArtifact($0) }
            .filter(matchesNameHint(_:))
            .max(by: olderThan(_:_:))

        if let outputCandidate {
            return outputCandidate
        }

        let buildDirectory = projectURL.appendingPathComponent(".build", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: buildDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var candidates: [URL] = []
        for case let url as URL in enumerator {
            guard isDynamicLibrary(url),
                  !isDebugSymbolsArtifact(url),
                  !isHotReloadRelinkArtifact(url),
                  matchesNameHint(url),
                  isRegularFile(url) else {
                continue
            }

            candidates.append(url)
        }

        return candidates.max(by: olderThan(_:_:))
    }

    private func candidateURL(from token: String) -> URL? {
        let url = URL(fileURLWithPath: token, relativeTo: projectURL).standardizedFileURL
        guard isDynamicLibrary(url),
              !isDebugSymbolsArtifact(url),
              !isHotReloadRelinkArtifact(url),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return url
    }

    private func isDynamicLibrary(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "dylib", "so", "dll":
            return true
        default:
            return false
        }
    }

    private func matchesNameHint(_ url: URL) -> Bool {
        guard let dylibName, !dylibName.isEmpty else {
            return true
        }

        let filename = url.deletingPathExtension().lastPathComponent.lowercased()
        let hint = dylibName.lowercased()
        return filename == hint || filename == "lib\(hint)" || filename.contains(hint)
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func isDebugSymbolsArtifact(_ url: URL) -> Bool {
        url.pathComponents.contains { $0.hasSuffix(".dSYM") }
    }

    private func isHotReloadRelinkArtifact(_ url: URL) -> Bool {
        url.deletingPathExtension().lastPathComponent.hasSuffix(".hot-reload")
    }

    private func olderThan(_ lhs: URL, _ rhs: URL) -> Bool {
        modificationDate(lhs) < modificationDate(rhs)
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func relinkHotReloadDylibIfPossible(_ dylibURL: URL) throws -> URL {
        #if canImport(Darwin)
        let moduleName = moduleName(fromDylib: dylibURL)
        let buildDirectory = dylibURL.deletingLastPathComponent()
        let linkFileListURL = buildDirectory
            .appendingPathComponent("\(moduleName).product", isDirectory: true)
            .appendingPathComponent("Objects.LinkFileList")

        guard FileManager.default.fileExists(atPath: linkFileListURL.path) else {
            return dylibURL
        }

        let linkFileList = try String(contentsOf: linkFileListURL, encoding: .utf8)
        let objectPaths = targetObjectPaths(
            in: linkFileList,
            productModuleName: moduleName
        )

        guard !objectPaths.isEmpty else {
            return dylibURL
        }

        let outputURL = buildDirectory.appendingPathComponent("lib\(moduleName).hot-reload.dylib")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let arguments = [
            "swiftc",
            "-emit-library",
        ] + objectPaths + [
            "-o",
            outputURL.path,
            "-Xlinker",
            "-undefined",
            "-Xlinker",
            "dynamic_lookup",
            "-Xlinker",
            "-install_name",
            "-Xlinker",
            "@rpath/\(outputURL.lastPathComponent)"
        ]

        try runRelinkCommand(arguments: arguments)
        return outputURL
        #else
        return dylibURL
        #endif
    }

    private func targetObjectPaths(
        in linkFileList: String,
        productModuleName: String
    ) -> [String] {
        let objectPaths = linkFileList
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { $0.hasSuffix(".o") }
            .filter { FileManager.default.fileExists(atPath: $0) }

        let productTargetBuildPath = "/\(productModuleName).build/"
        let productTargetObjectPaths = objectPaths.filter { $0.contains(productTargetBuildPath) }
        if !productTargetObjectPaths.isEmpty {
            return productTargetObjectPaths
        }

        let sourceBasenames = hotReloadSourceBasenames()
        guard !sourceBasenames.isEmpty else {
            return []
        }

        let selectedBuildDirectories = Set(
            objectPaths.compactMap { objectPath -> String? in
                guard let sourceBasename = sourceBasename(fromObjectPath: objectPath),
                      sourceBasenames.contains(sourceBasename) else {
                    return nil
                }

                return URL(fileURLWithPath: objectPath)
                    .deletingLastPathComponent()
                    .path
            }
        )

        guard !selectedBuildDirectories.isEmpty else {
            return []
        }

        return objectPaths.filter { objectPath in
            selectedBuildDirectories.contains(
                URL(fileURLWithPath: objectPath)
                    .deletingLastPathComponent()
                    .path
            )
        }
    }

    private func hotReloadSourceBasenames() -> Set<String> {
        var basenames: Set<String> = []

        for path in sourcePaths {
            let sourceURL = URL(fileURLWithPath: path, relativeTo: projectURL).standardizedFileURL
            collectSourceBasenames(at: sourceURL, into: &basenames)
        }

        return basenames
    }

    private func collectSourceBasenames(
        at sourceURL: URL,
        into basenames: inout Set<String>
    ) {
        guard let sourceValues = try? sourceURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey]) else {
            return
        }

        if sourceValues.isDirectory != true {
            if sourceValues.isRegularFile == true {
                basenames.insert(sourceURL.lastPathComponent)
            }
            return
        }

        guard let enumerator = FileManager.default.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }

            basenames.insert(url.lastPathComponent)
        }
    }

    private func sourceBasename(fromObjectPath objectPath: String) -> String? {
        let objectBasename = URL(fileURLWithPath: objectPath).lastPathComponent
        guard objectBasename.hasSuffix(".o") else {
            return nil
        }

        return String(objectBasename.dropLast(2))
    }

    private func moduleName(fromDylib dylibURL: URL) -> String {
        let name = dylibURL.deletingPathExtension().lastPathComponent
        if name.hasPrefix("lib") {
            return String(name.dropFirst(3))
        }

        return name
    }

    private func runRelinkCommand(arguments: [String]) throws {
        let process = Process()
        process.currentDirectoryURL = projectURL
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw AdaUIHotReloadBuildError.buildFailed(
                command: Self.shellCommand(["xcrun"] + arguments),
                exitCode: process.terminationStatus,
                output: output
            )
        }
    }

    private static func shellEscaped(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func shellCommand(_ arguments: [String]) -> String {
        arguments.map(shellEscaped(_:)).joined(separator: " ")
    }
}

@safe
@MainActor
private final class AdaUIHotReloadDynamicLibrary {
    typealias MakeViewFunction = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer?

    private var sourceURL: URL?
    private let symbolName: String
    private let logger: Logger
    private let copiedLibrariesDirectory: URL

    private var generation = 0
    private var makeViewFunction: MakeViewFunction?
    private var handles: [UnsafeMutableRawPointer] = unsafe []

    init(
        symbolName: String,
        logger: Logger
    ) {
        self.symbolName = symbolName
        self.logger = logger
        self.copiedLibrariesDirectory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("AdaUIHotReload", isDirectory: true)
    }

    func reload(from sourceURL: URL) {
        self.sourceURL = sourceURL
        reload()
    }

    private func reload() {
        unsafe makeViewFunction = nil

        do {
            unsafe makeViewFunction = try loadMakeViewFunction()
            logger.info("Loaded AdaUI hot reload dylib \(sourceURL?.path ?? "<missing>")")
        } catch {
            logger.error("Failed to load AdaUI hot reload dylib \(sourceURL?.path ?? "<missing>"): \(error)")
        }
    }

    func makeView(id: String) -> UIView? {
        if unsafe makeViewFunction == nil {
            guard sourceURL != nil else {
                return nil
            }

            reload()
        }

        guard let makeViewFunction = unsafe makeViewFunction else {
            return nil
        }

        let rawView = unsafe id.withCString { idPointer in
            unsafe makeViewFunction(idPointer)
        }

        guard let rawView = unsafe rawView else {
            return nil
        }

        return unsafe Unmanaged<UIView>.fromOpaque(rawView).takeRetainedValue()
    }

    private func loadMakeViewFunction() throws -> MakeViewFunction {
        #if canImport(Darwin) || canImport(Glibc)
        let copiedURL = try copySourceDylib()
        guard let handle = unsafe dlopen(copiedURL.path, RTLD_NOW | RTLD_LOCAL) else {
            throw AdaUIHotReloadPluginError.dynamicLibraryOpenFailed(Self.lastDynamicLibraryError())
        }

        guard let symbol = unsafe dlsym(handle, symbolName) else {
            throw AdaUIHotReloadPluginError.symbolNotFound(symbolName)
        }

        unsafe handles.append(handle)
        return unsafe unsafeBitCast(symbol, to: MakeViewFunction.self)
        #else
        throw AdaUIHotReloadPluginError.unsupportedPlatform
        #endif
    }

    private func copySourceDylib() throws -> URL {
        guard let sourceURL else {
            throw AdaUIHotReloadPluginError.dynamicLibraryMissing("<not built yet>")
        }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw AdaUIHotReloadPluginError.dynamicLibraryMissing(sourceURL.path)
        }

        try FileManager.default.createDirectory(
            at: copiedLibrariesDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        generation += 1
        let processID = ProcessInfo.processInfo.processIdentifier
        let sourceName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension.isEmpty ? "dylib" : sourceURL.pathExtension
        let copiedURL = copiedLibrariesDirectory
            .appendingPathComponent("\(sourceName)-\(processID)-\(generation)")
            .appendingPathExtension(pathExtension)

        if FileManager.default.fileExists(atPath: copiedURL.path) {
            try FileManager.default.removeItem(at: copiedURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: copiedURL)
        return copiedURL
    }

    private static func lastDynamicLibraryError() -> String {
        #if canImport(Darwin) || canImport(Glibc)
        guard let error = unsafe dlerror() else {
            return "Unknown dynamic library loading error."
        }

        return unsafe String(cString: error)
        #else
        return "Dynamic library loading is not available on this platform."
        #endif
    }
}

private enum AdaUIHotReloadPluginError: Error, CustomStringConvertible {
    case dynamicLibraryMissing(String)
    case dynamicLibraryOpenFailed(String)
    case symbolNotFound(String)
    case unsupportedPlatform

    var description: String {
        switch self {
        case .dynamicLibraryMissing(let path):
            return "Dynamic library does not exist at \(path)."
        case .dynamicLibraryOpenFailed(let message):
            return message
        case .symbolNotFound(let symbol):
            return "Symbol \(symbol) was not found."
        case .unsupportedPlatform:
            return "Dynamic library hot reload is not supported on this platform."
        }
    }
}

private enum AdaUIHotReloadBuildError: Error, CustomStringConvertible {
    case buildFailed(command: String, exitCode: Int32?, output: String)
    case dynamicLibraryNotFound(command: String, output: String)

    var description: String {
        switch self {
        case .buildFailed(let command, let exitCode, let output):
            let status = exitCode.map { "exit code \($0)" } ?? "unknown exit code"
            return "AdaUI hot reload build failed (\(status)) for command `\(command)`.\n\(output)"
        case .dynamicLibraryNotFound(let command, let output):
            return """
            AdaUI hot reload build succeeded but no dynamic library artifact was found.
            Command: `\(command)`
            Add a dynamic library product for the hot reload target, set `buildProduct`/`ADAUI_HOT_RELOAD_PRODUCT`, or provide `buildCommand`.
            \(output)
            """
        }
    }
}
