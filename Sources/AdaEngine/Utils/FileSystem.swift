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
    
    public func itemExists(at url: URL) -> Bool {
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
