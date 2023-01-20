//
//  FileSystem.swift
//  
//
//  Created by v.prusakov on 1/20/23.
//

import Foundation

// A representation of file system.
public class FileSystem {
    
    public enum SearchDirectoryPath {
        case downloadsDirectory
        case documentDirectory
        case cachesDirectory
    }
    
    public static let `current`: FileSystem = {
        #if os(macOS) || os(iOS) || os(tvOS) || os(Linux) || os(Windows) || os(Android)
        return FoundationFileSystem()
        #else
        fatalError("Currently not supported file system")
        #endif
    }()
    
    public var applicationFolderURL: URL {
        fatalErrorMethodNotImplemented()
    }
    
    public func url(for searchPath: SearchDirectoryPath, create: Bool = false) throws -> URL {
        fatalErrorMethodNotImplemented()
    }
    
    public func fileExists(at url: URL) -> Bool {
        fatalErrorMethodNotImplemented()
    }
    
    public func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func copy(from fromURL: URL, to toURL: URL) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func move(from fromURL: URL, to toURL: URL) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func removeItem(at url: URL) throws {
        fatalErrorMethodNotImplemented()
    }
    
    public func createFile(at url: URL, contents: Data?) -> Bool {
        fatalErrorMethodNotImplemented()
    }
    
    public func readFile(at url: URL) -> Data? {
        fatalErrorMethodNotImplemented()
    }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(Linux) || os(Windows) || os(Android)

final class FoundationFileSystem: FileSystem {
    
    let fileManager: Foundation.FileManager = .default
    
    override var applicationFolderURL: URL {
        URL(fileURLWithPath: fileManager.currentDirectoryPath)
    }
    
    override func url(for searchPath: SearchDirectoryPath, create: Bool = false) throws -> URL {
        
        let searchPathDir: FileManager.SearchPathDirectory
        
        switch searchPath {
        case .downloadsDirectory:
            searchPathDir = .downloadsDirectory
        case .documentDirectory:
            searchPathDir = .documentDirectory
        case .cachesDirectory:
            searchPathDir = .cachesDirectory
        }
        
        return try self.fileManager.url(for: searchPathDir, in: .userDomainMask, appropriateFor: nil, create: create)
    }
    
    override func fileExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    override func copy(from fromURL: URL, to toURL: URL) throws {
        try self.fileManager.copyItem(at: fromURL, to: toURL)
    }
    
    override func move(from fromURL: URL, to toURL: URL) throws {
        try self.fileManager.moveItem(at: fromURL, to: toURL)
    }
    
    override func removeItem(at url: URL) throws {
        try self.fileManager.removeItem(at: url)
    }
    
    override func createFile(at url: URL, contents: Data?) -> Bool {
        return self.fileManager.createFile(atPath: url.pathExtension, contents: contents)
    }
    
    override func createDirectory(at url: URL, withIntermediateDirectories flag: Bool) throws {
        try self.fileManager.createDirectory(at: url, withIntermediateDirectories: flag)
    }
    
    override func readFile(at url: URL) -> Data? {
        return self.fileManager.contents(atPath: url.path)
    }
}

#endif
