//
//  AudioResource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

import Foundation

/// An audio resource that can be played.
/// The AudioResource class stores audio that you can play in your scene or entire app.
public final class AudioResource: Resource {
    
    enum Source {
        case file(URL)
        case data(Data)
    }
    
    public var resourceName: String = ""
    public var resourcePath: String = ""
    internal let source: Source
    
    public static var resourceType: ResourceType = .audio
    
    public required init(asset decoder: AssetDecoder) throws {
        if decoder.assetMeta.filePath.pathExtension == Self.resourceType.fileExtenstion {
            guard let data = FileSystem.current.readFile(at: decoder.assetMeta.filePath) else {
                throw AssetDecodingError.decodingProblem("Can't read file at path")
            }
            
            self.source = .data(data)
        } else {
            self.source = .file(decoder.assetMeta.filePath)
        }
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        
    }
    
}
