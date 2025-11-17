//
//  MiniAudioEngine.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

import AdaECS
import AdaUtils
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import miniaudio
import Math

enum MAError: LocalizedError {
    case failed(String, ma_result)
    
    var errorDescription: String? {
        switch self {
        case .failed(let string, let result):
            "[MiniAudioEngine] Code: \(result) Error: \(string)"
        }
    }
}

struct MiniAudioEngine: AudioEngine, @unchecked Sendable {

    static func getFromWorld(_ world: borrowing AdaECS.World) -> MiniAudioEngine? {
        world.getResource(Self.self)
    }
    
    private final class Engine {
        var enginePtr: UnsafeMutablePointer<ma_engine> = .allocate(
            capacity: MemoryLayout.size(ofValue: ma_engine.self)
        )

        init() throws {
            var config = ma_engine_config_init()
            config.channels = 2
            let result = ma_engine_init(&config, enginePtr)
            if result != MA_SUCCESS {
                throw AudioError.engineInitializationFailed
            }
        }

        deinit {
            ma_engine_uninit(enginePtr)
        }
    }

    private let engine: Engine

    init() throws {
        self.engine = try Engine()
    }
    
    // MARK: - AudioEngine
    
    func start() throws {
        let result = ma_engine_start(engine.enginePtr)
        if result != MA_SUCCESS {
            throw MAError.failed("Failed to start", result)
        }
    }
    
    func stop() throws {
        let result = ma_engine_stop(engine.enginePtr)
        if result != MA_SUCCESS {
            throw MAError.failed("Failed to stop", result)
        }
    }
    
    func update(_ deltaTime: AdaUtils.TimeInterval) { }

    func makeSound(from url: URL) throws -> Sound {
        try MiniSound(from: url, engine: engine.enginePtr)
    }
    
    func makeSound(from data: Data) throws -> Sound {
        try MiniSound(from: data, engine: engine.enginePtr)
    }
    
    func getAudioListener(at index: Int) -> AudioEngineListener {
        if index > ma_engine_get_listener_count(engine.enginePtr) - 1 {
            fatalError("[MiniAudioEngine] Listener not found")
        }
        
        return MiniAudioEngineListener(engine: engine.enginePtr, listenerIndex: UInt32(index))
    }
}

// MARK: - MiniAudioEngineListener -

final class MiniAudioEngineListener: AudioEngineListener, @unchecked Sendable {
    
    private let engine: UnsafeMutablePointer<ma_engine>
    let listenerIndex: UInt32
    
    init(engine: UnsafeMutablePointer<ma_engine>, listenerIndex: UInt32) {
        self.engine = engine
        self.listenerIndex = listenerIndex
    }
    
    var position: Vector3 {
        get {
            let position = ma_engine_listener_get_position(engine, self.listenerIndex)
            return [position.x, position.y, position.z]
        }
        
        set {
            ma_engine_listener_set_position(engine, listenerIndex, newValue.x, newValue.y, newValue.z)
        }
    }
    
    var direction: Vector3 {
        get {
            let position = ma_engine_listener_get_direction(engine, listenerIndex)
            return [position.x, position.y, position.z]
        }
        
        set {
            ma_engine_listener_set_direction(engine, listenerIndex, newValue.x, newValue.y, newValue.z)
        }
    }
    
    var velocity: Vector3 {
        get {
            let position = ma_engine_listener_get_velocity(engine, listenerIndex)
            return [position.x, position.y, position.z]
        }
        
        set {
            ma_engine_listener_set_velocity(engine, listenerIndex, newValue.x, newValue.y, newValue.z)
        }
    }
    
    var isEnabled: Bool {
        get {
            return ma_engine_listener_is_enabled(engine, listenerIndex) == 1
        }
        
        set {
            ma_engine_listener_set_enabled(engine, listenerIndex, newValue ? 1 : 0)
        }
    }
    
    var worldUp: Vector3 {
        get {
            let position = ma_engine_listener_get_world_up(engine, listenerIndex)
            return [position.x, position.y, position.z]
        }
        
        set {
            ma_engine_listener_set_world_up(engine, listenerIndex, newValue.x, newValue.y, newValue.z)
        }
    }
    
    func setCone(innerAngle: Angle, outerAngle: Angle, outerGain: Float) {
        ma_engine_listener_set_cone(engine, listenerIndex, innerAngle.radians, outerAngle.radians, outerGain)
    }
    
    var innerAngle: Angle {
        var radians: Float = 0
        ma_engine_listener_get_cone(engine, listenerIndex, &radians, nil, nil)

        return .radians(radians)
    }
    
    var outerAngle: Angle {
        var radians: Float = 0
        ma_engine_listener_get_cone(engine, listenerIndex, nil, &radians, nil)

        return .radians(radians)
    }
    
    var outerGain: Float {
        var gain: Float = 0
        ma_engine_listener_get_cone(engine, listenerIndex, nil, nil, &gain)
        return gain
    }
}

// MARK: - Sound -

final class MiniSound: Sound {
    
    private(set) var state: SoundState = .ready
    
    private var completionHandler: (() -> Void)?
    
    private var sound: UnsafeMutablePointer<ma_sound>? = .allocate(capacity: MemoryLayout.size(ofValue: ma_sound.self))

    init(from fileURL: URL, engine: UnsafeMutablePointer<ma_engine>!) throws {
        let flags = MA_SOUND_FLAG_DECODE.rawValue | MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue
        let result = fileURL.path.withCString { pFilePath in
            ma_sound_init_from_file(engine, pFilePath, flags, nil, nil, sound)
        }
        if result != MA_SUCCESS {
            throw AudioError.soundInitializationFailed
        }
    }
    
    init(from data: Data, engine: UnsafeMutablePointer<ma_engine>!) throws {
        var data = data
        let flags = MA_SOUND_FLAG_DECODE.rawValue | MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue
        let result = data.withUnsafeMutableBytes { ptr in
            ma_sound_init_from_data_source(engine, ptr.baseAddress!, flags, nil, sound)
        }
        
        if result != MA_SUCCESS {
            throw AudioError.soundInitializationFailed
        }
    }
    
    private init(prototype: MiniSound) throws {
        let engine = ma_sound_get_engine(prototype.sound)
        let result = ma_sound_init_copy(engine, prototype.sound, 0, nil, sound)

        if result != MA_SUCCESS {
            throw AudioError.soundInitializationFailed
        }
    }
    
    deinit {
        ma_sound_uninit(sound)
    }
    
    func copy() throws -> Sound {
        return try MiniSound(prototype: self)
    }
    
    func update(_ deltaTime: AdaUtils.TimeInterval) {
        
    }
    
    var volume: Float {
        get {
            ma_sound_get_volume(sound)
        }
        
        set {
            ma_sound_set_volume(sound, newValue)
        }
    }
    
    var pitch: Float {
        get {
            ma_sound_get_pitch(sound)
        }
        
        set {
            ma_sound_set_pitch(sound, newValue)
        }
    }
    
    var position: Vector3 {
        get {
            let position = ma_sound_get_position(sound)
            return [position.x, position.y, position.z]
        }
        set {
            ma_sound_set_position(sound, newValue.x, newValue.y, newValue.z)
        }
    }
    
    var isLooping: Bool {
        get {
            return ma_sound_is_looping(sound) == 1
        }
        
        set {
            ma_sound_set_looping(sound, newValue ? 1 : 0)
        }
    }
    
    func start() {
        self.state = .playing
        ma_sound_start(sound)
    }
    
    func stop() {
        self.state = .stopped
        self.stop(resetPlaybackPosition: true, notifyCallback: false)
    }
    
    func pause() {
        self.state = .paused
        self.stop(resetPlaybackPosition: false, notifyCallback: false)
    }
    
    func onCompleteHandler(_ block: @escaping () -> Void) {
        let pointer = Unmanaged<MiniSound>.passUnretained(self).toOpaque()
        
        ma_sound_set_end_callback(sound, { userData, _ in
            let soundObj = Unmanaged<MiniSound>.fromOpaque(userData!).takeUnretainedValue()
            soundObj.state = .finished
            soundObj.completionHandler?()
        }, pointer)
        
        self.completionHandler = block
    }
    
    // MARK: - Private
    
    private func stop(resetPlaybackPosition: Bool, notifyCallback: Bool) {
        ma_sound_stop(sound)

        if resetPlaybackPosition {
            ma_sound_seek_to_pcm_frame(sound, 0)
        }
        
        if notifyCallback {
            self.completionHandler?()
        }
    }
}
