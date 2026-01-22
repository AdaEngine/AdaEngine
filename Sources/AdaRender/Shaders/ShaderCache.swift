//
//  ShaderCache.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/17/23.
//

import AdaUtils
import Foundation
import Logging
@unsafe @preconcurrency import Yams

/// Contains information about shader changes and store/load spirv binary in cache folder.
enum ShaderCache {

    private typealias Cache = [String : [ShaderStage : ShaderCache]]
    
    struct ShaderCache: Equatable, Codable {
        let sourceHashValue: Int
        let headers: [ShaderSource.IncludeSearchPath]
        let version: Int
    }

    private static let fileSystem = FileSystem.current
    private static let logger = Logger(label: "org.adaengine.shader-cache")

    static func hasChanges(for source: ShaderSource, version: Int) -> Set<ShaderStage> {
        guard let cacheKey = source.fileURL?.relativeString else {
            return []
        }
        
        var cacheData = self.getCacheData()
        let cache = cacheData[cacheKey]
        
        var changedValues: Set<ShaderStage> = []

        for stage in source.stages {
            guard let shaderSource = source.getSource(for: stage) else {
                continue
            }
            
            let shaderCache = ShaderCache(
                sourceHashValue: shaderSource.uniqueHashValue,
                headers: source.includeSearchPaths,
                version: version
            )
            
            if cache == nil || (cache?[stage] != shaderCache) {
                changedValues.insert(stage)
                cacheData[cacheKey, default: [:]][stage] = shaderCache
                
                Self.removeReflection(for: source.fileURL!, stage: stage)
            }
        }
        
        if !changedValues.isEmpty {
            self.saveCacheData(cacheData)
        }
        
        return changedValues
    }
    
    // MARK: Save/Load SPIRV

    static func getCachedDeviceCompiledShader(for source: ShaderSource, stage: ShaderStage) -> DeviceCompiledShader? {
        guard let fileURL = source.fileURL else {
            return nil
        }
        
        let path = fileURL.prepareCachePath
        
        do {
            let cacheDir = try self.getCacheDirectory()
            let cacheFile = cacheDir
                .appending(path: path, directoryHint: .isDirectory)
                .appending(path: "cache-\(stage.rawValue).device-compiled-shader.\(Constants.shaderCacheFileExtension)", directoryHint: .notDirectory)
            guard let data = fileSystem.readFile(at: cacheFile) else {
                return nil
            }
            return try YAMLDecoder().decode(DeviceCompiledShader.self, from: data)
        } catch {
            logger.error("Failed to get cached device compiled shader: \(error)")
            return nil
        } 
    }
    
    static func getCachedShader(
        for source: ShaderSource,
        stage: ShaderStage,
        version: Int,
        entryPoint: String
    ) -> SpirvBinary? {
        guard let fileURL = source.fileURL else {
            return nil
        }
        
        let path = fileURL.prepareCachePath
        
        do {
            let cacheFile = try self.getCacheDirectory()
                .appending(path: path, directoryHint: .isDirectory)
                .appendingPathExtension("cache-\(stage.rawValue)-\(version).spv")
            guard let data = fileSystem.readFile(at: cacheFile) else {
                return nil
            }
            return SpirvBinary(
                stage: stage,
                data: data,
                language: source.language,
                entryPoint: entryPoint,
                version: version
            )
        } catch {
            logger.error("Failed to get cached device compiled shader: \(error)")
            return nil
        }
    }
    
    static func save(_ spirvBin: SpirvBinary, source: ShaderSource, stage: ShaderStage, version: Int) throws {
        guard let fileURL = source.fileURL else {
            throw CompileError.failed("Source file URL not found")
        }
        
        let path = fileURL.prepareCachePath
        
        let cacheDir = try self.getCacheDirectory()
        
        let cacheURL = cacheDir
            .appending(path: path, directoryHint: .isDirectory)

        if !fileSystem.itemExists(at: cacheURL) {
            try fileSystem.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
            
        let cacheFile = cacheURL
            .appending(path: "cache-\(stage.rawValue)-\(version).spv", directoryHint: .notDirectory)
        _ = fileSystem.createFile(at: cacheFile, contents: spirvBin.data)
    }
    
    // MARK: - Save/Load Reflection
    
    static func saveReflection(_ reflectionData: ShaderReflectionData, for source: ShaderSource, stage: ShaderStage) throws {
        guard reflectionData.isEmpty == false else {
            return
        }
        
        guard let fileURL = source.fileURL else {
            return
        }
        
        let path = fileURL.prepareCachePath
        
        let cacheDir = try self.getCacheDirectory()
        
        let cacheURL = cacheDir
            .appending(path: path, directoryHint: .isDirectory)

        if !fileSystem.itemExists(at: cacheURL) {
            try fileSystem.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }

        let cacheFile = cacheURL
            .appending(path: "cache-\(stage.rawValue).\(Constants.shaderCacheFileExtension)", directoryHint: .notDirectory)
        
        let stringData = try YAMLEncoder().encode(reflectionData)
        _ = fileSystem.createFile(at: cacheFile, contents: stringData.data(using: .utf8)!)
    }

    static func saveDeviceCompiledShader(_ compiledShader: DeviceCompiledShader, for source: ShaderSource, stage: ShaderStage) throws {
        guard let fileURL = source.fileURL else {
            throw CompileError.failed("Source file URL not found")
        }
        
        let path = fileURL.prepareCachePath
        
        let cacheDir = try self.getCacheDirectory()

        let cacheURL = cacheDir
            .appending(path: path, directoryHint: .isDirectory)

        if !fileSystem.itemExists(at: cacheURL) {
            try fileSystem.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        
        let cacheFile = cacheURL
            .appending(path: "cache-\(stage.rawValue).device-compiled-shader.\(Constants.shaderCacheFileExtension)", directoryHint: .notDirectory)
        
        let stringData = try YAMLEncoder().encode(compiledShader)
        _ = fileSystem.createFile(at: cacheFile, contents: stringData.data(using: .utf8)!)
    }
    
    static func getReflection(for source: ShaderSource, stage: ShaderStage) -> ShaderReflectionData? {
        guard let fileURL = source.fileURL else {
            return nil
        }
        
        let path = fileURL.prepareCachePath

        do {
            let cacheFile = try self.getCacheDirectory()
                .appending(path: path, directoryHint: .isDirectory)
                .appending(path: "cache-\(stage.rawValue).\(Constants.shaderCacheFileExtension)", directoryHint: .notDirectory)
            guard let data = fileSystem.readFile(at: cacheFile) else {
                return nil
            }
            return try YAMLDecoder().decode(ShaderReflectionData.self, from: data)
        } catch {
            logger.error("Failed to get cached reflection: \(error)")
            return nil
        }
    }
    
    static func removeReflection(for fileURL: URL, stage: ShaderStage) {
        let path = fileURL.prepareCachePath
        
        do {
            let cacheFile = try self.getCacheDirectory()
                .appending(path: path, directoryHint: .isDirectory)
                .appending(path: "cache-\(stage.rawValue).\(Constants.shaderCacheFileExtension)", directoryHint: .notDirectory)
            try fileSystem.removeItem(at: cacheFile)
        } catch {
            logger.error("Failed to remove cached reflection: \(error)")
        }
    }
    
    // MARK: - Private
    
    private static func getCacheData() -> Cache {
        self.createCacheDirectoryIfNeeded()
        
        do {
            let cacheFile = try getCacheFile()
            guard let data = fileSystem.readFile(at: cacheFile) else {
                return [:]
            }
            
            return try YAMLDecoder().decode(Cache.self, from: data)
        } catch {
            fatalError("[ShaderCache] \(error)")
        }
    }
    
    private static func saveCacheData(_ cacheData: Cache) {
        self.createCacheDirectoryIfNeeded()
        
        do {
            let cacheFile = try getCacheFile()
            let string = try YAMLEncoder().encode(cacheData)
            _ = fileSystem.createFile(at: cacheFile, contents: string.data(using: .utf8)!)
        } catch {
            fatalError("[ShaderCache] \(error)")
        }
    }
    
    static func getCacheDirectory() throws -> URL {
        return try self.fileSystem
            .url(for: .cachesDirectory)
            .appendingPathComponent(Constants.cacheDirectoryName)
            .appending(path: Constants.shadersDirectoryName, directoryHint: .isDirectory)
    }
    
    private static func getCacheFile() throws -> URL {
        try self.getCacheDirectory().appending(path: Constants.shaderCacheFileName, directoryHint: .notDirectory)
    }
    
    private static func createCacheDirectoryIfNeeded() {
        do {
            let cacheDir = try getCacheDirectory()
            
            if fileSystem.itemExists(at: cacheDir) {
                return
            }
            
            return try fileSystem.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        } catch {
            fatalError("[ShaderCache] \(error)")
        }
    }

    enum Constants {
        static let cacheDirectoryName = "AdaEngine"
        static let shadersDirectoryName = "Shaders"
        static let shaderCacheFileName = "ShaderCache.cache"
        static let shaderCacheFileExtension = "yaml"
        static let separator = "/"
    }

    enum CompileError: LocalizedError {
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .failed(let msg):
                return "[ShaderCache] Failed: \(msg)."
            }
        }
    }
}

private extension URL {
    var prepareCachePath: String {
        return self.pathComponents.suffix(3).joined(separator: ShaderCache.Constants.separator).replacingOccurrences(of: ".bundle", with: "")
    }
}
