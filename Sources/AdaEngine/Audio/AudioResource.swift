//
//  AudioResource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

import Foundation

/// An audio resource that can be played.
/// The AudioResource class stores audio data that you can play in your scene or entire app.
public final class AudioResource: Resource {
    
    public var resourceName: String = ""
    public var resourcePath: String = ""
    private let sound: Sound
    
    public static var resourceType: ResourceType = .audio
    
    public required init(asset decoder: AssetDecoder) throws {
        if decoder.assetMeta.filePath.pathExtension == Self.resourceType.fileExtenstion {
            guard let data = FileSystem.current.readFile(at: decoder.assetMeta.filePath) else {
                throw AssetDecodingError.decodingProblem("Can't read file at path")
            }
            
            self.sound = try AudioServer.shared.engine.makeSound(from: data)
        } else {
            self.sound = try AudioServer.shared.engine.makeSound(from: decoder.assetMeta.filePath)
        }
    }
    
    private init(sound: Sound) {
        self.sound = sound
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalErrorMethodNotImplemented()
    }
    
    // TODO: (Vlad) I'm not sure that is a good solution to copy sound.
    /// Returns copy of sound.
    internal func getSound() throws -> Sound {
        return try self.sound.copy()
    }
    
    // MARK: - Public
    
    /// Create a new instance of audio resource from a file.
    /// - Note: Supports `WAV` format.
    public static func create(from url: URL) throws -> AudioResource {
        let sound = try AudioServer.shared.engine.makeSound(from: url)
        return AudioResource(sound: sound)
    }
    
    /// Create a new instance of audio resource from a data.
    public static func create(from data: Data) throws -> AudioResource {
        let sound = try AudioServer.shared.engine.makeSound(from: data)
        return AudioResource(sound: sound)
    }
}
