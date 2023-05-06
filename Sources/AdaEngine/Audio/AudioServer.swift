//
//  AudioServer.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/3/23.
//

import Math

enum AudioError: Error {
    case engineInitializationFailed
    case soundInitializationFailed
}

protocol AudioEngine {
    
    func start() throws
    
    func stop() throws
    
    func update(_ deltaTime: TimeInterval)
    
    func makeSound(from url: URL) throws -> Sound
    
    func makeSound(from data: Data) throws -> Sound
    
    func getAudioListener(at index: Int) -> AudioEngineListener
}

/// A controller that manages audio playback of a resource.
///
/// You receive an audio playback controller by calling an entity’s ``Entity/prepareAudio(_:)`` method.
/// You typically pass an ``AudioResource`` instance to this call that tells the playback controller how to stream the contents of an audio file.
public class AudioPlaybackController {
    
    /// The resource that provides the audio stream.
    public let resource: AudioResource
    
    let sound: Sound
    
    /// The entity from which the audio stream emanates.
    public internal(set) weak var entity: Entity?
    
    init(resource: AudioResource, sound: Sound) {
        self.resource = resource
        self.sound = sound
    }
    
    /// A Boolean that indicates whether playback is currently active.
    public var isPlaying: Bool {
        return self.sound.state == .playing
    }
    
    public var volume: Float {
        get {
            self.sound.volume
        }
        
        set {
            self.sound.volume = newValue
        }
    }
    
    public func setLoop(_ isLooping: Bool) -> Self {
        self.sound.isLooping = isLooping
        return self
    }
    
    /// Plays the audio resource.
    public func play() {
        self.sound.start()
    }
    
    /// Pauses playback of the audio resource while maintaining the position in the audio stream.
    public func pause() {
        self.sound.pause()
    }
    
    /// Stops playback of the audio resource and discards the location in the audio stream.
    public func stop() {
        self.sound.stop()
    }
    
    /// A closure that the playback controller executes when it comes to the end of the audio stream.
    public func onCompleteHandler(_ block: @escaping () -> Void) -> Self {
        self.sound.onCompleteHandler(block)
        return self
    }
    
    public func setVolume(_ volume: Float) -> Self {
        self.volume = volume
        return self
    }
}

/// An instance that managed audio in the AdaEngine.
public final class AudioServer {
    
    public private(set) static var shared: AudioServer!
    
    let engine: AudioEngine
    
    private init(engine: AudioEngine) {
        self.engine = engine
    }
    
    static func initialize() throws {
        let engine = try MiniAudioEngine()
        self.shared = AudioServer(engine: engine)
    }
    
    func update(_ deltaTime: TimeInterval) {
        self.engine.update(deltaTime)
    }
    
    func start() throws {
        try self.engine.start()
    }
    
    func stop() throws {
        try self.engine.stop()
    }
    
    private func makeSound(from resource: AudioResource) throws -> Sound {
        switch resource.source {
        case .data(let data):
            return try self.engine.makeSound(from: data)
        case .file(let file):
            return try self.engine.makeSound(from: file)
        }
    }
    
    // MARK: - Public
    
    public func prepareAudio(_ resource: AudioResource) -> AudioPlaybackController {
        do {
            let sound = try self.makeSound(from: resource)
            return AudioPlaybackController(resource: resource, sound: sound)
        } catch {
            fatalError("[AudioServer] Can't create sound from resource \(error.localizedDescription)")
        }
    }
}

/// Interface describes audio listener entity in spatial audio scene.
protocol AudioEngineListener: AnyObject {
    
    var position: Vector3 { get set }
    var direction: Vector3 { get set }
    var velocity: Vector3 { get set }
    var worldUp: Vector3 { get set }
    
    var isEnabled: Bool { get set }
    
    func setCone(innerAngle: Angle, outerAngle: Angle, outerGain: Float)
    
    var innerAngle: Angle { get }
    var outerAngle: Angle { get }
    var outerGain: Float { get }
}
