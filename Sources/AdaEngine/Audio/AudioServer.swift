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

public final class AudioPlaybackController {
    
    public let resource: AudioResource
    
    init(resource: AudioResource) {
        self.resource = resource
    }
    
    public func setLoop(_ isLooping: Bool) {
        self.resource.sound.isLooping = isLooping
    }
    
    public func play() {
        self.resource.sound.start()
    }
    
    public func pause() {
        self.resource.sound.pause()
    }
    
    public func stop() {
        self.resource.sound.stop()
    }
    
    public func onCompleteHandler(_ block: @escaping () -> Void) {
        self.resource.sound.onCompleteHandler(block)
    }
}

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
    
    // MARK: - Public
    
    public func prepareAudio(_ resource: AudioResource) -> AudioPlaybackController {
        return AudioPlaybackController(resource: resource)
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
