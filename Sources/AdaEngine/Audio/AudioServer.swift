//
//  AudioServer.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/3/23.
//

@_implementationOnly import miniaudio
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
}

final class MiniSound: Sound {
    
    private var sound: ma_sound
    
    init(from fileURL: URL, engine: UnsafeMutablePointer<ma_engine>!) throws {
        self.sound = ma_sound()
        
        let flags = MA_SOUND_FLAG_DECODE.rawValue | MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue
        
        let result = fileURL.path.withCString { pFilePath in
            ma_sound_init_from_file(engine, pFilePath, flags, nil, nil, &sound)
        }
        
        if result != MA_SUCCESS {
            throw AudioError.soundInitializationFailed
        }
    }
    
    init(from data: Data, engine: UnsafeMutablePointer<ma_engine>!) throws {
        
        self.sound = ma_sound()
        
        var data = data
        let flags = MA_SOUND_FLAG_DECODE.rawValue | MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue
        let result = data.withUnsafeMutableBytes { ptr in
            ma_sound_init_from_data_source(engine, ptr.baseAddress!, flags, nil, &sound)
        }
        
        if result != MA_SUCCESS {
            throw AudioError.soundInitializationFailed
        }
    }
    
    deinit {
        ma_sound_uninit(&sound)
    }
    
    func update(_ deltaTime: TimeInterval) {
        
    }
    
    var volume: Float {
        get {
            ma_sound_get_volume(&sound)
        }
        
        set {
            ma_sound_set_volume(&sound, newValue)
        }
    }
    
    var pitch: Float {
        get {
            ma_sound_get_pitch(&sound)
        }
        
        set {
            ma_sound_set_pitch(&sound, newValue)
        }
    }
    
    var position: Vector3 {
        get {
            let position = ma_sound_get_position(&sound)
            return [position.x, position.y, position.z]
        }
        set {
            ma_sound_set_position(&sound, newValue.x, newValue.y, newValue.z)
        }
    }
    
    var isLooping: Bool {
        get {
            return ma_sound_is_looping(&sound) == 1
        }
        
        set {
            ma_sound_set_looping(&sound, newValue ? 1 : 0)
        }
    }
    
    func start() {
        ma_sound_start(&sound)
    }
    
    func stop() {
        ma_sound_stop(&sound)
    }
    
    func pause() {
        
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
    
}

class MiniAudioEngine: AudioEngine {
    
    private var engine: ma_engine
    
    init() throws {
        var config = ma_engine_config()
        config.channels = 2
        self.engine = ma_engine()
        
        if ma_engine_init(&config, &engine) != MA_SUCCESS {
            throw AudioError.engineInitializationFailed
        }
    }
    
    deinit {
        ma_engine_uninit(&engine)
    }
    
    // AudioEngine
    
    func start() throws {
        ma_engine_start(&engine)
    }
    
    func stop() throws {
        ma_engine_stop(&engine)
    }
    
    func update(_ deltaTime: TimeInterval) {
        let graph = ma_engine_get_node_graph(&engine)
    }
    
    func makeSound(from url: URL) throws -> Sound {
        try MiniSound(from: url, engine: &engine)
    }
    
    func makeSound(from data: Data) throws -> Sound {
        try MiniSound(from: data, engine: &engine)
    }
}
