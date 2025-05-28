//
//  ShaderCache.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/17/23.
//

import AdaUtils
import Foundation
@preconcurrency import Yams

/// Contains information about shader changes and store/load spirv binary in cache folder.
enum ShaderCache {

    private typealias Cache = [String : [ShaderStage : ShaderCache]]
    
    struct ShaderCache: Equatable, Codable {
        let sourceHashValue: Int
        let headers: [ShaderSource.IncludeSearchPath]
        let version: Int
    }

    private static let fileSystem = FileSystem.current

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
    
    static func getCachedShader(
        for source: ShaderSource,
        stage: ShaderStage,
        version: Int,
        entryPoint: String
    ) -> SpirvBinary? {
        guard let fileURL = source.fileURL else {
            return nil
        }
        
        let path = fileURL.pathComponents.suffix(3).joined(separator: "_")
        
        guard let cacheFile = try? self.getCacheDirectory()
            .appendingPathComponent(path)
            .deletingPathExtension()
            .appendingPathExtension("cache-\(stage.rawValue)-\(version).spv") else {
            return nil
        }
        
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
    }
    
    static func save(_ spirvBin: SpirvBinary, source: ShaderSource, stage: ShaderStage, version: Int) throws {
        guard let fileURL = source.fileURL else {
            return
        }
        
        let path = fileURL.pathComponents.suffix(3).joined(separator: "_")
        
        let cacheDir = try self.getCacheDirectory()
        
        let cacheURL = cacheDir
            .appendingPathComponent(path)
            .deletingPathExtension()
            .appendingPathExtension("cache-\(stage.rawValue)-\(version).spv")
        
        _ = fileSystem.createFile(at: cacheURL, contents: spirvBin.data)
    }
    
    // MARK: - Save/Load Reflection
    
    static func saveReflection(_ reflectionData: ShaderReflectionData, for source: ShaderSource, stage: ShaderStage) throws {
        guard let fileURL = source.fileURL else {
            return
        }
        
        let path = fileURL.pathComponents.suffix(3).joined(separator: "_")
        
        let cacheDir = try self.getCacheDirectory()
        
        let cacheURL = cacheDir
            .appendingPathComponent(path)
            .deletingPathExtension()
            .appendingPathExtension("cache-\(stage.rawValue).ref")
        
        let stringData = try YAMLEncoder().encode(reflectionData)
        _ = fileSystem.createFile(at: cacheURL, contents: stringData.data(using: .utf8)!)
    }
    
    static func getReflection(for source: ShaderSource, stage: ShaderStage) -> ShaderReflectionData? {
        guard let fileURL = source.fileURL else {
            return nil
        }
        
        let path = fileURL.pathComponents.suffix(3).joined(separator: "_")
        
        guard let cacheFile = try? self.getCacheDirectory()
            .appendingPathComponent(path)
            .deletingPathExtension()
            .appendingPathExtension("cache-\(stage.rawValue).ref") else {
            return nil
        }
        
        guard let data = fileSystem.readFile(at: cacheFile) else {
            return nil
        }
        
        return try? YAMLDecoder().decode(ShaderReflectionData.self, from: data)
    }
    
    static func removeReflection(for fileURL: URL, stage: ShaderStage) {
        let path = fileURL.pathComponents.suffix(3).joined(separator: "_")
        
        guard let cacheFile = try? self.getCacheDirectory()
            .appendingPathComponent(path)
            .deletingPathExtension()
            .appendingPathExtension("cache-\(stage.rawValue).ref") else {
            return
        }
        
        try? fileSystem.removeItem(at: cacheFile)
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
    
    private static func getCacheDirectory() throws -> URL {
        return try self.fileSystem
            .url(for: .cachesDirectory)
            .appendingPathComponent("AdaEngine")
            .appendingPathComponent("Shaders")
    }
    
    private static func getCacheFile() throws -> URL {
        try self.getCacheDirectory().appendingPathComponent("ShaderCache.cache")
    }
    
    private static func createCacheDirectoryIfNeeded() {
        do {
            let cacheDir = try getCacheDirectory()
            
            if fileSystem.itemExists(at: cacheDir) {
                return
            }
            
            return try fileSystem.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        } catch {
            fatalError("[ShaderCache] \(error.localizedDescription)")
        }
    }
}
