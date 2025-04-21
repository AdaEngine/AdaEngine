//
//  AudioResource.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

import Foundation

/// An audio resource that can be played.
/// The AudioResource class stores audio data that you can play in your scene or entire app.
public final class AudioResource: Resource, @unchecked Sendable {
    
    public var resourceMetaInfo: ResourceMetaInfo?
    
    private let sound: Sound
    
    public static let resourceType: ResourceType = .audio

    public required init(asset decoder: AssetDecoder) async throws {
//        if await decoder.assetMeta.filePath.pathExtension == Self.resourceType.fileExtenstion {
//            self.sound = try AudioServer.shared.engine.makeSound(from: decoder.assetData)
//        } else {
            self.sound = try AudioServer.shared.engine.makeSound(from: decoder.assetMeta.filePath)
//        }
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
