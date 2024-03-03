//
//  AudioEngine.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

/// Interface that works with audio.
protocol AudioEngine {
    
    /// Starts audio engine.
    func start() throws
    
    /// Stop audio engine.
    func stop() throws
    
    func update(_ deltaTime: TimeInterval)
    
    /// Create a new sound instance from file url.
    func makeSound(from url: URL) throws -> Sound
    
    /// Create a new sound instance from data.
    func makeSound(from data: Data) throws -> Sound
    
    /// Returns audio listener object at index.
    /// Max count of listeners depends on implementation of ``AudioEngine``.
    func getAudioListener(at index: Int) -> AudioEngineListener
}
