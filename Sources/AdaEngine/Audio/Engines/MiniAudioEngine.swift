//
//  MiniAudioEngine.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/6/23.
//

@_implementationOnly import MiniAudioBindings
import Math

private let MA_SOUND_FLAG_DECODE: ada.ma_sound_flags = ada.ma_sound_flags(0x00000002)
private let MA_SOUND_FLAG_NO_SPATIALIZATION: ada.ma_sound_flags = ada.ma_sound_flags(0x00004000)
private let MA_SUCCESS: ada.ma_result = ada.ma_result(0)
private let MA_ERROR: ada.ma_result = ada.ma_result(-1)

final class MiniAudioEngine: AudioEngine {
    
    private var engine: OpaquePointer!

    init() throws {
        self.engine = ada.ma_make_engine()

        var config = ada.ma_engine_config()
        config.channels = 2

        let result = ada.ma_engine_init(&config, engine)

        if result != MA_SUCCESS {
            throw AudioError.engineInitializationFailed
        }
    }
    
    deinit {
        ada.ma_engine_uninit(engine)
    }
    
    // MARK: - AudioEngine
    
    func start() throws {
        ada.ma_engine_start(engine)
    }
    
    func stop() throws {
        ada.ma_engine_stop(engine)
    }
    
    func update(_ deltaTime: TimeInterval) {
        
    }
    
    func makeSound(from url: URL) throws -> Sound {
        try MiniSound(from: url, engine: engine)
    }
    
    func makeSound(from data: Data) throws -> Sound {
        try MiniSound(from: data, engine: engine)
    }
    
    func getAudioListener(at index: Int) -> AudioEngineListener {
        if index > ada.ma_engine_get_listener_count(engine) - 1 {
            fatalError("[MiniAudioEngine] Listener not found")
        }
        
        return MiniAudioEngineListener(engine: engine, listenerIndex: UInt32(index))
    }
}

// MARK: - MiniAudioEngineListener -

final class MiniAudioEngineListener: AudioEngineListener {
    
    private let engine: OpaquePointer?
    let listenerIndex: UInt32
    
    init(engine: OpaquePointer?, listenerIndex: UInt32) {
        self.engine = engine
        self.listenerIndex = listenerIndex
    }
    
    var position: Vector3 {
        get {
            let position = ada.ma_engine_listener_get_position(engine, self.listenerIndex)
            return [position.x, position.y, position.z]
        }
        
        set {
            ada.ma_engine_listener_set_position(engine, listenerIndex, newValue.x, newValue.y, newValue.z)
        }
    }
    
    var direction: Vector3 {
        get {
            let position = ada.ma_engine_listener_get_direction(engine, listenerIndex)
            return [position.x, position.y, position.z]
        }
        
        set {
            ada.ma_engine_listener_set_direction(engine, listenerIndex, newValue.x, newValue.y, newValue.z)
        }
    }
    
    var velocity: Vector3 {
        get {
            let position = ada.ma_engine_listener_get_velocity(engine, listenerIndex)
            return [position.x, position.y, position.z]
        }
        
        set {
            ada.ma_engine_listener_set_velocity(engine, listenerIndex, newValue.x, newValue.y, newValue.z)
        }
    }
    
    var isEnabled: Bool {
        get {
            return ada.ma_engine_listener_is_enabled(engine, listenerIndex) == 1
        }
        
        set {
            ada.ma_engine_listener_set_enabled(engine, listenerIndex, newValue ? 1 : 0)
        }
    }
    
    var worldUp: Vector3 {
        get {
            let position = ada.ma_engine_listener_get_world_up(engine, listenerIndex)
            return [position.x, position.y, position.z]
        }
        
        set {
            ada.ma_engine_listener_set_world_up(engine, listenerIndex, newValue.x, newValue.y, newValue.z)
        }
    }
    
    func setCone(innerAngle: Angle, outerAngle: Angle, outerGain: Float) {
        ada.ma_engine_listener_set_cone(engine, listenerIndex, innerAngle.radians, outerAngle.radians, outerGain)
    }
    
    var innerAngle: Angle {
        var radians: Float = 0
        ada.ma_engine_listener_get_cone(engine, listenerIndex, &radians, nil, nil)

        return .radians(radians)
    }
    
    var outerAngle: Angle {
        var radians: Float = 0
        ada.ma_engine_listener_get_cone(engine, listenerIndex, nil, &radians, nil)

        return .radians(radians)
    }
    
    var outerGain: Float {
        var gain: Float = 0
        ada.ma_engine_listener_get_cone(engine, listenerIndex, nil, nil, &gain)
        return gain
    }
}

// MARK: - Sound -

final class MiniSound: Sound {
    
    private(set) var state: SoundState = .ready
    
    private var completionHandler: (() -> Void)?
    
    private var sound: OpaquePointer?

    init(from fileURL: URL, engine: OpaquePointer?) throws {
        self.sound = ada.ma_make_sound()
        let flags = MA_SOUND_FLAG_DECODE.rawValue | MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue

        let result = fileURL.path.withCString { pFilePath in
            ada.ma_sound_init_from_file(engine, pFilePath, flags, nil, sound)
        }
        
        if result != MA_SUCCESS {
            throw AudioError.soundInitializationFailed
        }
    }
    
    init(from data: Data, engine: OpaquePointer?) throws {
        self.sound = ada.ma_make_sound()
        var data = data
        let flags = MA_SOUND_FLAG_DECODE.rawValue | MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue
        let result = data.withUnsafeMutableBytes { ptr in
            ada.ma_sound_init_from_data_source(engine, ptr.baseAddress!, flags, nil, sound)
        }
        
        if result != MA_SUCCESS {
            throw AudioError.soundInitializationFailed
        }
    }
    
    private init(prototype: MiniSound) throws {
        self.sound = ada.ma_make_sound()
        var engine = ada.ma_sound_get_engine(prototype.sound)
        let result = ada.ma_sound_init_copy(engine, prototype.sound, 0, nil, sound)

        if result != MA_SUCCESS {
            throw AudioError.soundInitializationFailed
        }
    }
    
    deinit {
        ada.ma_sound_uninit(sound)
    }
    
    func copy() throws -> Sound {
        return try MiniSound(prototype: self)
    }
    
    func update(_ deltaTime: TimeInterval) {
        
    }
    
    var volume: Float {
        get {
            ada.ma_sound_get_volume(sound)
        }
        
        set {
            ada.ma_sound_set_volume(sound, newValue)
        }
    }
    
    var pitch: Float {
        get {
            ada.ma_sound_get_pitch(sound)
        }
        
        set {
            ada.ma_sound_set_pitch(sound, newValue)
        }
    }
    
    var position: Vector3 {
        get {
            let position = ada.ma_sound_get_position(sound)
            return [position.x, position.y, position.z]
        }
        set {
            ada.ma_sound_set_position(sound, newValue.x, newValue.y, newValue.z)
        }
    }
    
    var isLooping: Bool {
        get {
            return ada.ma_sound_is_looping(sound) == 1
        }
        
        set {
            ada.ma_sound_set_looping(sound, newValue ? 1 : 0)
        }
    }
    
    func start() {
        self.state = .playing
        ada.ma_sound_start(sound)
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
        
        ada.ma_sound_set_end_callback(sound, { userData, _ in
            let soundObj = Unmanaged<MiniSound>.fromOpaque(userData!).takeUnretainedValue()
            soundObj.state = .finished
            soundObj.completionHandler?()
        }, pointer)
        
        self.completionHandler = block
    }
    
    // MARK: - Private
    
    private func stop(resetPlaybackPosition: Bool, notifyCallback: Bool) {
        ada.ma_sound_stop(sound)

        if resetPlaybackPosition {
            ada.ma_sound_seek_to_pcm_frame(sound, 0)
        }
        
        if notifyCallback {
            self.completionHandler?()
        }
    }
}
